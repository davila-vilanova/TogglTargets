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

typealias RefreshAction = Action<Void, Void, APIAccessError>

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

    var refreshAllData: BindingTarget<Void> { get }
    var updateRunningEntry: Action<Void, Void, APIAccessError> { get }
}

class TogglAPIDataRetriever: TogglDataRetriever {

    internal let lifetime: Lifetime

    private let lifetimeToken: Lifetime.Token


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

    private lazy var _profile = MutableProperty<Profile?>(nil)
    internal lazy var profile = Property(_profile)


    // MARK: - Projects

    private let retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction

    private lazy var _projects = MutableProperty(IndexedProjects())
    internal lazy var projects = Property(_projects)


    // MARK: - Reports

    internal var twoPartReportPeriod: BindingTarget<TwoPartTimeReportPeriod> { return _twoPartReportPeriod.deoptionalizedBindingTarget }

    private let _twoPartReportPeriod = MutableProperty<TwoPartTimeReportPeriod?>(nil)

    private let retrieveReportsNetworkAction: RetrieveReportsNetworkAction

    private let _reports = MutableProperty(IndexedTwoPartTimeReports())
    internal lazy var reports = Property(_reports)


    // MARK: - RunningEntry

    private let retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction

    private lazy var _runningEntry: MutableProperty<RunningEntry?> = {
        let m = MutableProperty<RunningEntry?>(nil)
        m <~ retrieveRunningEntryNetworkAction.values
        return m
    }()

    internal lazy var runningEntry = Property(_runningEntry)

    // MARK: - Refresh actions

    func stateForRefreshAction(with underlyingAction: Action<)

    lazy var updateRunningEntry = RefreshAction(state: urlSession.map { $0 != nil }.and(retrieveRunningEntryNetworkAction.isEnabled)) { [weak self] in
        if let retriever = self {
            retriever.retrieveRunningEntryNetworkAction <~ retriever.urlSession.producer.take(first: 1)

        }
        return SignalProducer.empty
    }

    init() {

    }
}
