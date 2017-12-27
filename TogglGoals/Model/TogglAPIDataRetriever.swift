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

/// Retrieves user data from the Toggl API keeping data that has dependencies up to date with the state
/// of its parent data:
/// * Attempts to retrieve the user profile from the Toggl API corresponding to the latest input value
///   received through the `apiCredential` binding target. (All the other API operations also depend on the
///   availability of a valid API credential and fetching the reports needs the credential to be a token
///   credential, `TogglAPITokenCredential`)
/// * Retrieves the projects corresponding to the workspace IDs referenced by the latest fetched profile,
///   using the latest available API credential. Combines the projects from all workspaces.
/// * Retrieves two-part time reports corresponding to the workspace IDs referenced by the latest fetched
///   profile and delimited by the periods of time represented by the `TwoPartTimeReportPeriod` values
///   received through the `twoPartReportPeriod` binding target. The reports are fetched whenever new
///   workspace IDs or new time period values become available.
/// * Retrieves the running time on demand.
protocol TogglAPIDataRetriever: class {

    // MARK: - Exposed binding targets

    /// Binding target for the API credential values that will be used to authenticate as a specific
    /// user against the Toggl API.
    /// - note: retrieving the reports needs the input value to be of type `TogglAPITokenCredential`
    var apiCredential: BindingTarget<TogglAPICredential?> { get }

    /// Binding target for the two-part time periods that will delimit the time periods for which the
    /// reports will be fetched from the Toggl API.
    var twoPartReportPeriod: BindingTarget<TwoPartTimeReportPeriod> { get }


    // MARK: - Retrieved data

    /// Holds and publishes `Profile` values as they become available.
    var profile: Property<Profile?> { get }

    /// Holds and publishes `IndexedProjects` values, or projects indexed by project ID, as they
    /// become available.
    var projects: Property<IndexedProjects?> { get }

    /// Holds and publishes `IndexedTwoPartTimeReports` values, or two-part time reports indexed by
    /// project ID, as they become available.
    var reports: Property<IndexedTwoPartTimeReports?> { get }

    /// Holds and publishes the current time entry or `nil` for no time entry whenever it is retrieved.
    var runningEntry: Property<RunningEntry?> { get }


    // MARK: - Refresh actions

    /// Triggers an attempt to retrieve the user profile, projects, reports and
    /// currently running entry.
    var refreshAllData: RefreshAction { get }

    /// Triggers and attempt to retrieve the currently running time entry.
    var updateRunningEntry: RefreshAction { get }


    // MARK: - Activity and Errors

    /// Publishes `APIAccessError` values as they happen.
    var errors: Signal<APIAccessError, NoError> { get }

    /// Publishes the activities with which that this retrievar is engaged
    /// at any given time.
    var currentActivities: Property<Set<RetrievalActivity>> { get }
}

/// Represents a type of retrieval activity that can be driven by a TogglAPIDataRetriever.
enum RetrievalActivity {
    case profile
    case projects
    case reports
    case runningEntry
}


/// `CachedTogglAPIDataRetriever` is a `TogglAPIDataRetriever` that relies on locally stored data to
/// return cached results when running on a device that happens to be offline, or to return preliminary
/// results more quickly when the device is online. The locally stored data is updated whenever a fresh
/// value is retrieved from the Toggl API.
class CachedTogglAPIDataRetriever: TogglAPIDataRetriever {

    /// The lifetime associated with this instance.
    internal let lifetime: Lifetime

    /// The lifetime token associated with `lifetime`.
    private let lifetimeToken: Lifetime.Token

    /// The scheduler used internally by this instance.
    private let scheduler = QueueScheduler.init(name: "TogglAPIDataRetriever-scheduler")


    // MARK: - API credential and URL session

    /// Binding target for the API credential values that will be used to authenticate as a specific
    /// user against the Toggl API.
    /// - note: retrieving the reports needs the input value to be of type `TogglAPITokenCredential`
    internal var apiCredential: BindingTarget<TogglAPICredential?> { return _apiCredential.bindingTarget }

    /// Backs the `apiCredential` binding target.
    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)

    /// Generates a `URLSession` instance based on the latest value received through `apiCredential`.
    private lazy var urlSession = Property<URLSession?>(
        initial: nil, then: _apiCredential.producer.skipNil().map(URLSession.init))


    // MARK: - Profile

    /// The `Action` used to retrieve profiles from the Toggl API.
    private let retrieveProfileNetworkAction: RetrieveProfileNetworkAction

    /// The `Action` used to retrieve profiles from the local cache.
    private let retrieveProfileCacheAction: RetrieveProfileCacheAction

    /// The `Action` used to store profiles into the local cache.
    private let storeProfileCacheAction: StoreProfileCacheAction

    /// Holds and publishes `Profile` values as they become available, that is, as they are retrieved
    /// from the Toggl API or from the local cache.
    internal lazy var profile =
        Property<Profile?>(initial: nil, then: Signal.merge(retrieveProfileNetworkAction.values,
                                                            retrieveProfileCacheAction.values.skipNil()))


    // MARK: - Projects

    /// The `Action` used to retrieve projects from the Toggl API.
    private var retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction!

    /// Holds and publishes `IndexedProjects` values, or projects indexed by project ID, as they
    /// become available.
    internal lazy var projects = Property<IndexedProjects?>(initial: nil, then: retrieveProjectsNetworkAction.values)


    // MARK: - Reports

    /// Binding target for the two-part time periods that will delimit the time periods for which the
    /// reports will be retrieved.
    internal var twoPartReportPeriod: BindingTarget<TwoPartTimeReportPeriod> {
        return _twoPartReportPeriod.deoptionalizedBindingTarget
    }

    /// Backing for `twoPartReportPeriod`.
    private let _twoPartReportPeriod = MutableProperty<TwoPartTimeReportPeriod?>(nil)

    /// The `Action` used to retrieve reports from the Toggl API.
    private var retrieveReportsNetworkAction: RetrieveReportsNetworkAction!

    /// Holds and publishes `IndexedTwoPartTimeReports` values, or two-part time reports indexed by
    /// project ID, as they become available.
    internal lazy var reports = Property<IndexedTwoPartTimeReports?>(initial: nil, then: retrieveReportsNetworkAction.values)


    // MARK: - RunningEntry

    /// The `Action` used to retrieve the currently running time entry from the Toggl API.
    private let retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction

    /// Holds and publishes the current time entry or `nil` for no time entry whenever it is retrieved.
    internal lazy var runningEntry = Property<RunningEntry?>(initial: nil, then: retrieveRunningEntryNetworkAction.values)


    // MARK: - Refresh actions

    /// Applying this `Action` will start an attempt to grab from the Toggl API the currently running entry
    /// by executing the underlying retrieveRunningEntryNetworkAction.
    /// This `Action` is only enabled if an API credential is available and if the underlying action is enabled.
    lazy var updateRunningEntry: RefreshAction = {
        let action = RefreshAction(state: urlSession.map { $0 != nil }.and(retrieveRunningEntryNetworkAction.isEnabled)) { _ in
            SignalProducer(value: ())
        }
        retrieveRunningEntryNetworkAction <~ urlSession.producer.sample(on: action.values)
        return action
    }()


    /// Triggers an attempt to retrieve the user profile, projects, reports and
    /// currently running entry.
    lazy var refreshAllData: RefreshAction = {
        let action = RefreshAction(state: urlSession.map { $0 != nil }.and(retrieveProfileNetworkAction.isEnabled)) { _ in
            SignalProducer(value: ())
        }
        retrieveProfileNetworkAction <~ urlSession.producer.sample(on: action.values)
        retrieveRunningEntryNetworkAction <~ urlSession.producer.sample(on: action.values)
        return action
    }()


    // MARK: - Errors

    /// Publishes `APIAccessError` values as they happen.
    lazy var errors: Signal<APIAccessError, NoError> = Signal.merge(
        retrieveProfileNetworkAction.errors.logEvents(identifier: "profile errors"),
        retrieveProjectsNetworkAction.errors,
        retrieveReportsNetworkAction.errors,
        retrieveRunningEntryNetworkAction.errors)


    /// Publishes the activities with which that this retriever is engaged
    /// at any given time.
    lazy var currentActivities: Property<Set<RetrievalActivity>> =
        Property(initial: Set<RetrievalActivity>(),
                 then: SignalProducer.combineLatest(retrieveProfileNetworkAction.isExecuting,
                                                    retrieveProjectsNetworkAction.isExecuting,
                                                    retrieveReportsNetworkAction.isExecuting,
                                                    retrieveRunningEntryNetworkAction.isExecuting)
                    .map { (isExecuting) -> [RetrievalActivity : Bool] in
                        [.profile : isExecuting.0, .projects : isExecuting.1, .reports : isExecuting.2, .runningEntry : isExecuting.3]
                    }.map {
                        let filtered = $0.filter { (_, isExecuting) in isExecuting }
                        return Set<RetrievalActivity>(filtered.keys)
    })


    /// Initializes a `CachedTogglAPIDataRetriever` that will use the provided actions to fetch data from
    /// the Toggl API and from the local cache, and to store data into the local cache.
    /// - parameters:
    ///   - retrieveProfileNetworkAction: The `Action` used to retrieve profiles
    ///                                   from the Toggl API.
    ///   - retrieveProfileCacheAction: The `Action` used to retrieve profiles
    ///                                 from the local cache.
    ///   - storeProfileCacheAction: The `Action` used to store profiles into the
    ///                              local cache.
    ///   - retrieveProjectsNetworkActionMaker: A `RetrieveProjectsNetworkActionMaker`
    ///                                         to generate the `Action` used to
    ///                                         retrieve projects from the Toggl API.
    ///   - retrieveReportsNetworkActionMaker: A `RetrieveProjectsNetworkActionMaker`
    ///                                        to generate the `Action` used to
    ///                                        retrieve reports from the Toggl API.
    ///   - retrieveRunningEntryNetworkAction: The `Action` used to retrieve the
    ///                                        currently running time entry from
    ///                                        the Toggl API.
    init(retrieveProfileNetworkAction: RetrieveProfileNetworkAction,
         retrieveProfileCacheAction: RetrieveProfileCacheAction,
         storeProfileCacheAction: StoreProfileCacheAction,
         retrieveProjectsNetworkActionMaker: RetrieveProjectsNetworkActionMaker,
         retrieveReportsNetworkActionMaker: RetrieveReportsNetworkActionMaker,
         retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction) {

        (lifetime, lifetimeToken) = Lifetime.make()

        self.retrieveProfileNetworkAction = retrieveProfileNetworkAction
        self.retrieveProfileCacheAction = retrieveProfileCacheAction
        self.storeProfileCacheAction = storeProfileCacheAction
        self.retrieveRunningEntryNetworkAction = retrieveRunningEntryNetworkAction
        self.retrieveProjectsNetworkAction = retrieveProjectsNetworkActionMaker(urlSession)
        self.retrieveReportsNetworkAction = retrieveReportsNetworkActionMaker(urlSession)

        retrieveProfileNetworkAction <~ urlSession.signal
            .throttle(while: retrieveProfileNetworkAction.isExecuting, on: scheduler)
        storeProfileCacheAction <~ retrieveProfileNetworkAction.values
            .throttle(while: storeProfileCacheAction.isExecuting, on: scheduler)

        let workspaceIDs = profile.producer.skipNil().map { $0.workspaces.map { $0.id } }
        retrieveProjectsNetworkAction <~ workspaceIDs
            .throttle(while: retrieveProjectsNetworkAction.isExecuting, on: scheduler)

        retrieveReportsNetworkAction <~ SignalProducer.combineLatest(workspaceIDs,
                                                                     _twoPartReportPeriod.producer.skipNil())
            .throttle(while: retrieveReportsNetworkAction.isExecuting, on: scheduler)

        // This action needs a little nudge because its input is not connected
        // to anything and we want to retrieve the cached profile right after
        // starting up.
        retrieveProfileCacheAction <~ SignalProducer(value: ()).start(on: scheduler)
    }
}
