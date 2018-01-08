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

    // Publishes updates to the status of this data retriever. Each update
    /// consists of a `RetrievalActivity` and its corresponding `ActivityStatus`
    var status: SignalProducer<(RetrievalActivity, ActivityStatus), NoError> { get }
}

/// Represents a type of retrieval activity that can be driven by a TogglAPIDataRetriever.
enum RetrievalActivity {
    case profile
    case projects
    case reports
    case runningEntry
}

typealias RetryAction = Action<Void, Void, NoError>

// Represents the status of a given activity
enum ActivityStatus {
    case executing
    case succeeded
    case error(APIAccessError, RetryAction)
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
    private var retrieveProfileNetworkAction: RetrieveProfileNetworkAction!

    /// The `Action` used to retrieve profiles from the local cache.
    private let retrieveProfileCacheAction: RetrieveProfileCacheAction

    /// The `Action` used to store profiles into the local cache.
    private let storeProfileCacheAction: StoreProfileCacheAction

    /// Holds and publishes `Profile` values as they become available, that is, as they are retrieved
    /// from the Toggl API or from the local cache.
    internal lazy var profile =
        Property<Profile?>(initial: nil, then: Signal.merge(retrieveProfileNetworkAction.values.logEvents(identifier: "retrieveProfileNetworkAction"),
                                                            retrieveProfileCacheAction.values.skipNil()))


    /// Publishes an array of `WorkspaceID` values derived from the latest `Profile`.
    private lazy var workspaceIDs: SignalProducer<[WorkspaceID], NoError> = profile.producer.skipNil().map { $0.workspaces.map { $0.id } }


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
    private var retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction!

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
        retrieveRunningEntryNetworkAction <~ SignalProducer(value: ())
        return action
    }()


    /// Triggers an attempt to retrieve the user profile, projects, reports and
    /// currently running entry.
    lazy var refreshAllData: RefreshAction = {
        let action = RefreshAction(state: urlSession.map { $0 != nil }.and(retrieveProfileNetworkAction.isEnabled)) { _ in
            SignalProducer(value: ())
        }
        retrieveProfileNetworkAction <~ SignalProducer(value: ())
        updateRunningEntry <~ SignalProducer(value: ())
        return action
    }()


    // MARK: - Activity and Errors

    lazy var status: SignalProducer<(RetrievalActivity, ActivityStatus), NoError> = {
        func extractStatus<ActionInput, ActionOutput>
            (from action: Action<ActionInput, ActionOutput, APIAccessError>,
             for activity: RetrievalActivity,
             retryErrorsWith inputForRetries: SignalProducer<ActionInput, NoError>)
            -> SignalProducer<(RetrievalActivity, ActivityStatus), NoError> {

                let executing = action.isExecuting.producer.filter { $0 }.map { _ in (activity, ActivityStatus.executing) }
                let succeeded = action.values.producer.map { _ in (activity, ActivityStatus.succeeded) }
                let heldInputForRetries = Property<ActionInput?>(initial: nil, then: inputForRetries)
                let retry = RetryAction(unwrapping: heldInputForRetries) { (inputValueForRetry, _) in
                    _ = action.apply(inputValueForRetry).start()
                    return SignalProducer.empty
                }
                let error = action.errors.producer.map { (activity, ActivityStatus.error($0, retry)) }

                return SignalProducer.merge(executing, succeeded, error)
        }

        func extractStatus<ActionOutput>(from action: Action<Void, ActionOutput, APIAccessError>,
                                         for activity: RetrievalActivity)
            -> SignalProducer<(RetrievalActivity, ActivityStatus), NoError> {
                return extractStatus(from: action, for: activity, retryErrorsWith: SignalProducer(value: ()))
        }

        return SignalProducer.merge(extractStatus(from: retrieveProfileNetworkAction, for: .profile),
                                    extractStatus(from: retrieveProjectsNetworkAction, for: .projects, retryErrorsWith: workspaceIDs),
                                    extractStatus(from: retrieveReportsNetworkAction, for: .reports, retryErrorsWith: SignalProducer.combineLatest(workspaceIDs, _twoPartReportPeriod.producer.skipNil())),
                                    extractStatus(from: retrieveRunningEntryNetworkAction, for: .runningEntry))
    }()


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
    init(retrieveProfileNetworkActionMaker: RetrieveProfileNetworkActionMaker,
         retrieveProfileCacheAction: RetrieveProfileCacheAction,
         storeProfileCacheAction: StoreProfileCacheAction,
         retrieveProjectsNetworkActionMaker: RetrieveProjectsNetworkActionMaker,
         retrieveReportsNetworkActionMaker: RetrieveReportsNetworkActionMaker,
         retrieveRunningEntryNetworkActionMaker: RetrieveRunningEntryNetworkActionMaker) {

        (lifetime, lifetimeToken) = Lifetime.make()

        self.retrieveProfileCacheAction = retrieveProfileCacheAction
        self.storeProfileCacheAction = storeProfileCacheAction
        self.retrieveProfileNetworkAction = retrieveProfileNetworkActionMaker(urlSession)
        self.retrieveProjectsNetworkAction = retrieveProjectsNetworkActionMaker(urlSession)
        self.retrieveReportsNetworkAction = retrieveReportsNetworkActionMaker(urlSession)
        self.retrieveRunningEntryNetworkAction = retrieveRunningEntryNetworkActionMaker(urlSession)

        let refreshProfileWhenOnURLSessionChange: Signal<Void, NoError> =
            urlSession.signal.skipNil()
                .throttle(while: retrieveProfileNetworkAction.isExecuting, on: scheduler)
                .map { _ in () }
        retrieveProfileNetworkAction <~ refreshProfileWhenOnURLSessionChange

        storeProfileCacheAction <~ retrieveProfileNetworkAction.values
            .throttle(while: storeProfileCacheAction.isExecuting, on: scheduler)

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
