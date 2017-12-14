//
//  TogglAPIDataRetriever.swift
//  TogglGoals
//
//  Created by David Dávila on 13.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

typealias RefreshAction = Action<Void, Void, NoError>

protocol TogglDataRetriever: class {
    // MARK: - Exposed binding targets

    var apiCredential: BindingTarget<TogglAPICredential?> { get }
    var twoPartReportPeriod: BindingTarget<TwoPartTimeReportPeriod> { get }


    // MARK: - Retrieved data

    var profile: Property<Profile?> { get }
    var projects: Property<IndexedProjects> { get }
    var reports: Property<IndexedTwoPartTimeReports> { get }
    var runningEntry: Property<RunningEntry?> { get }


    // MARK: - Refresh actions

    var refreshAllData: RefreshAction { get }
    var updateRunningEntry: RefreshAction { get }


    // MARK: - Errors

    var errors: Signal<APIAccessError, NoError> { get }
}

class TogglAPIDataRetriever: TogglDataRetriever {

    internal let lifetime: Lifetime

    private let lifetimeToken: Lifetime.Token

    private let scheduler = QueueScheduler.init(name: "TogglAPIDataRetriever-scheduler")


    // MARK: - API credential and URL session

    internal var apiCredential: BindingTarget<TogglAPICredential?> { return _apiCredential.bindingTarget }

    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)

    private lazy var urlSession: MutableProperty<URLSession?> = {
        let p = MutableProperty<URLSession?>(nil)
        p <~ _apiCredential.map(URLSession.init)
        return p
    }()

    // MARK: - Profile

    private let retrieveProfileNetworkAction: RetrieveProfileNetworkAction
    private let retrieveProfileCacheAction: RetrieveProfileCacheAction
    private let storeProfileCacheAction: StoreProfileCacheAction

    internal lazy var profile =
        Property<Profile?>(initial: nil, then: Signal.merge(retrieveProfileNetworkAction.values,
                                                            retrieveProfileCacheAction.values.skipNil()))


    // MARK: - Projects

    private let retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction

    internal lazy var projects = Property(initial: IndexedProjects(), then: retrieveProjectsNetworkAction.values)


    // MARK: - Reports

    internal var twoPartReportPeriod: BindingTarget<TwoPartTimeReportPeriod> {
        return _twoPartReportPeriod.deoptionalizedBindingTarget
    }

    private let _twoPartReportPeriod = MutableProperty<TwoPartTimeReportPeriod?>(nil)

    private let retrieveReportsNetworkAction: RetrieveReportsNetworkAction

    internal lazy var reports = Property(initial: IndexedTwoPartTimeReports(), then: retrieveReportsNetworkAction.values.logEvents(identifier: "report values"))


    // MARK: - RunningEntry

    private let retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction

    internal lazy var runningEntry = Property<RunningEntry?>(initial: nil, then: retrieveRunningEntryNetworkAction.values)

    // MARK: - Refresh actions

    /// Applying this action will start an attempt to grab from the Toggl API the currently running entry
    /// by executing the underlying retrieveRunningEntryNetworkAction.
    /// This action is only enabled if an API credential is available and if the underlying action is enabled.
    lazy var updateRunningEntry: RefreshAction = {
        let action = RefreshAction(state: urlSession.map { $0 != nil }.and(retrieveRunningEntryNetworkAction.isEnabled)) { _ in
            SignalProducer(value: ())
        }
        retrieveRunningEntryNetworkAction <~ urlSession.producer.sample(on: action.values)
        return action
    }()

    lazy var refreshAllData: RefreshAction = {
        let action = RefreshAction(state: urlSession.map { $0 != nil }.and(retrieveProfileNetworkAction.isEnabled)) { _ in
            SignalProducer(value: ())
        }
        retrieveProfileNetworkAction <~ urlSession.producer.sample(on: action.values)
        return action
    }()


    // MARK: - Errors

    lazy var errors: Signal<APIAccessError, NoError> = Signal.merge(retrieveProfileNetworkAction.errors,
                                                                    retrieveProjectsNetworkAction.errors,
                                                                    retrieveReportsNetworkAction.errors.logEvents(identifier: "report errors"),
                                                                    retrieveRunningEntryNetworkAction.errors)

    init(retrieveProfileNetworkAction: RetrieveProfileNetworkAction,
         retrieveProfileCacheAction: RetrieveProfileCacheAction,
         storeProfileCacheAction: StoreProfileCacheAction,
         retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction,
         retrieveReportsNetworkAction: RetrieveReportsNetworkAction,
         retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction) {

        (lifetime, lifetimeToken) = Lifetime.make()

        self.retrieveProfileNetworkAction = retrieveProfileNetworkAction
        self.retrieveProfileCacheAction = retrieveProfileCacheAction
        self.storeProfileCacheAction = storeProfileCacheAction
        self.retrieveProjectsNetworkAction = retrieveProjectsNetworkAction
        self.retrieveReportsNetworkAction = retrieveReportsNetworkAction
        self.retrieveRunningEntryNetworkAction = retrieveRunningEntryNetworkAction

        retrieveProfileNetworkAction <~ urlSession.signal
            .throttle(while: retrieveProfileNetworkAction.isExecuting, on: scheduler)
        storeProfileCacheAction <~ retrieveProfileNetworkAction.values
            .throttle(while: storeProfileCacheAction.isExecuting, on: scheduler)

        let workspaceIDs = profile.producer.skipNil().map { $0.workspaces.map { $0.id } }
        retrieveProjectsNetworkAction <~ SignalProducer.combineLatest(urlSession.producer.skipNil(), workspaceIDs)
            .throttle(while: retrieveProjectsNetworkAction.isExecuting, on: scheduler)

        retrieveReportsNetworkAction <~ SignalProducer.combineLatest(urlSession.producer.skipNil(),
                                                                     workspaceIDs,
                                                                     _twoPartReportPeriod.producer.skipNil())
            .throttle(while: retrieveReportsNetworkAction.isExecuting, on: scheduler)
    }
}
