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

    /// Triggers and attempt to refresh the reports from the Toggl API.
    var refreshReports: RefreshAction { get }

    // MARK: - Activity and Errors

    // Publishes updates to the status of this data retriever.
    var status: SignalProducer<ActivityStatus, NoError> { get }
}


typealias RetryAction = Action<Void, Void, NoError>

/// Represents the status of execution of an operation against the Toggl API.
enum ActivityStatus {

    /// Represents the kinds of operations against the Toggl API that
    /// `TogglAPIDataRetriever` supports.
    enum Activity {
        /// Retrieve the user profile from Toggl.
        case syncProfile

        /// Retrieve the user's projects.
        case syncProjects

        /// Retrieve the user's reports.
        case syncReports

        /// Retrieve the currently running time entry.
        case syncRunningEntry

        /// Represents all other `Activity` cases. Useful when combined with
        /// `ActivityStatus.succeeded` to denote that all data was successfully
        /// synchronized against the Toggl API.
        case all

        /// Count of `Activity` cases not including `all`.
        static var individualActivityCount = 4
    }

    /// The underlying `Activity` is executing. The result of this execution can
    /// be either the `succeeded` or the `error` case.
    case executing(Activity)

    /// The underlying `Activity` completed its execution successfully.
    case succeeded(Activity)

    /// The underlying `Activity` completed its execution with a failure.
    /// This case encloses in addition to the `Activity` the nature of the
    /// failure (`APIAccessError`) and the recovery action (`RetryAction`).
    case error(Activity, APIAccessError, RetryAction)

    /// Returns this case's underlying `Activity`.
    var activity: Activity {
        switch self {
        case .executing(let activity): return activity
        case .succeeded(let activity): return activity
        case .error(let activity, _, _): return activity
        }
    }

    /// Returns whether this is the `.executing` case.
    var isExecuting: Bool {
        switch self {
        case .executing(_): return true
        default: return false
        }
    }

    /// Returns whether this is the `.succeeded` case.
    var isSuccessful: Bool {
        switch self {
        case .succeeded: return true
        default: return false
        }
    }

    /// Returns whether this is the `.error` case.
    var isError: Bool {
        switch self {
        case .error(_, _, _): return true
        default: return false
        }
    }

    /// If this is the `.error` case, returns the `APIAccessError` that
    /// triggered it. Returns `nil` otherwise.
    var error: APIAccessError? {
        switch self {
        case .error(_, let err, _): return err
        default: return nil
        }
    }
}

extension ActivityStatus {
    static var allSuccessful: ActivityStatus {
        return ActivityStatus.succeeded(.all)
    }
}

extension ActivityStatus: Hashable {
    static func ==(lhs: ActivityStatus, rhs: ActivityStatus) -> Bool {
        if lhs.activity != rhs.activity {
            return false
        }

        switch lhs {
        case .executing(_): return rhs.isExecuting
        case .succeeded(_): return rhs.isSuccessful
        case .error(_, _, _): return rhs.isError // Error and retryAction themselves don't contribute to equality
        }
    }

    var hashValue: Int {
        switch self {
        case .executing(let activity): return activity.hashValue &* 829601
        case .succeeded(let activity): return activity.hashValue &* 829613
        case .error(let activity, _, _): return activity.hashValue &* 829627
        }
    }
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
        Property<Profile?>(initial: nil, then: Signal.merge(retrieveProfileNetworkAction.values,
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

    /// Applying this `Action` will start an attempt to fetch the currently running entry from the Toggl API
    /// by executing the underlying retrieveRunningEntryNetworkAction.
    /// This `Action` is enabled if an API credential is available and if the underlying action is enabled.
    lazy var updateRunningEntry: RefreshAction = {
        let action = RefreshAction(state: urlSession.map { $0 != nil }.and(retrieveRunningEntryNetworkAction.isEnabled)) { [weak self] _ in
            guard let retriever = self else {
                return SignalProducer.empty
            }

            retriever.retrieveRunningEntryNetworkAction <~ SignalProducer(value: ())
            return SignalProducer.empty
        }
        return action
    }()


    /// Triggers an attempt to retrieve the user profile, projects, reports and
    /// currently running entry.
    lazy var refreshAllData = RefreshAction(state: urlSession.map { $0 != nil }.and(retrieveProfileNetworkAction.isEnabled)) { [weak self] _ in
        // TODO revisit all weak and unowned references to self inside closures
        guard let retriever = self else {
            return SignalProducer.empty
        }

        retriever.retrieveProfileNetworkAction <~ SignalProducer(value: ())
        retriever.updateRunningEntry <~ SignalProducer(value: ())

        return SignalProducer.empty
    }

    /// Triggers an attempt to refresh the reports from the Toggl API.
    lazy var refreshReports: RefreshAction = {
        let state = Property.combineLatest(retrieveReportsNetworkAction.isEnabled,
                                           Property(initial: nil, then: workspaceIDs),
                                           _twoPartReportPeriod)
            .map { (input: (Bool, [WorkspaceID]?, TwoPartTimeReportPeriod?)) -> ([WorkspaceID], TwoPartTimeReportPeriod)? in
                let (isUnderlyingEnabled, workspaceIDsOrNil, periodOrNil) = input
                guard isUnderlyingEnabled,
                    let workspaceIDs = workspaceIDsOrNil,
                    let period = periodOrNil else {
                        return nil
                }
                return (workspaceIDs, period)
        }
        return RefreshAction(unwrapping: state) { [weak self] state in
            guard let retriever = self else {
                return SignalProducer.empty
            }

            retriever.retrieveReportsNetworkAction <~ SignalProducer(value: state)

            return SignalProducer.empty
        }
    }()


    // MARK: - Activity and Errors

    lazy var status: SignalProducer<ActivityStatus, NoError> = {
        func extractStatus<ActionInput, ActionOutput>
            (from action: Action<ActionInput, ActionOutput, APIAccessError>,
             for activity: ActivityStatus.Activity,
             retryErrorsWith inputForRetries: SignalProducer<ActionInput, NoError>)
            -> SignalProducer<ActivityStatus, NoError> {

                let executing = action.isExecuting.producer.filter { $0 }.map { _ in ActivityStatus.executing(activity) }
                let succeeded = action.values.producer.map { _ in ActivityStatus.succeeded(activity) }
                let heldInputForRetries = Property<ActionInput?>(initial: nil, then: inputForRetries)
                let retry = RetryAction(unwrapping: heldInputForRetries) { (inputValueForRetry, _) in
                    _ = action.apply(inputValueForRetry).start()
                    return SignalProducer.empty
                }
                let error = action.errors.producer.map { ActivityStatus.error(activity, $0, retry) }

                return SignalProducer.merge(executing, succeeded, error)
        }

        func extractStatus<ActionOutput>(from action: Action<Void, ActionOutput, APIAccessError>,
                                         for activity: ActivityStatus.Activity)
            -> SignalProducer<ActivityStatus, NoError> {
                return extractStatus(from: action, for: activity, retryErrorsWith: SignalProducer(value: ()))
        }

        return SignalProducer.merge(extractStatus(from: retrieveProfileNetworkAction, for: .syncProfile),
                                    extractStatus(from: retrieveProjectsNetworkAction, for: .syncProjects, retryErrorsWith: workspaceIDs),
                                    extractStatus(from: retrieveReportsNetworkAction, for: .syncReports, retryErrorsWith: SignalProducer.combineLatest(workspaceIDs, _twoPartReportPeriod.producer.skipNil())),
                                    extractStatus(from: retrieveRunningEntryNetworkAction, for: .syncRunningEntry))
    }()


    /// Initializes a `CachedTogglAPIDataRetriever` that will use the provided actions to fetch data from
    /// the Toggl API and from the local cache, and to store data into the local cache.
    /// - parameters:
    ///   - retrieveProfileNetworkActionMaker: A `RetrieveProfileNetworkActionMaker`
    ///                                        to generate the `Action` used to
    ///                                        retrieve the user profile from the
    ///                                        Toggl API.
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
    ///   - retrieveRunningEntryNetworkActionMaker: A `RetrieveRunningEntryNetworkActionMaker`
    ///                                             to generate the `Action` used
    ///                                             to retrieve the currently running
    ///                                             time entry from the Toggl API.
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

        // Get those `Properties` inside lazy properties initialized so they don't miss the first value
        _ = profile
        _ = projects
        _ = reports
        _ = runningEntry

        
        let refreshOnURLSessionChange: Signal<Void, NoError> =
            urlSession.signal.skipNil()
                .throttle(while: retrieveProfileNetworkAction.isExecuting, on: scheduler)
                .map { _ in () }
        refreshAllData <~ refreshOnURLSessionChange

        storeProfileCacheAction <~ retrieveProfileNetworkAction.values
            .throttle(while: storeProfileCacheAction.isExecuting, on: scheduler)

        retrieveProjectsNetworkAction <~ workspaceIDs
            .throttle(while: retrieveProjectsNetworkAction.isExecuting, on: scheduler)

        retrieveReportsNetworkAction <~ SignalProducer.combineLatest(workspaceIDs,
                                                                     _twoPartReportPeriod.producer.skipNil())
            .throttle(while: retrieveReportsNetworkAction.isExecuting, on: scheduler)

        // Nudge retrieve cache actions to pump the pipes
        retrieveProfileCacheAction <~ SignalProducer(value: ())
    }
}
