//
//  ActivityStatus.swift
//  TogglTargets
//
//  Created by David Dávila on 06.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation

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
        case .executing: return true
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
        case .error: return true
        default: return false
        }
    }

    var retryAction: RetryAction? {
        switch self {
        case .error(_, _, let retryAction): return retryAction
        default: return nil
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

extension ActivityStatus: Hashable {
    static func == (lhs: ActivityStatus, rhs: ActivityStatus) -> Bool {
        if lhs.activity != rhs.activity {
            return false
        }

        switch lhs {
        case .executing: return rhs.isExecuting
        case .succeeded: return rhs.isSuccessful
        case .error: return rhs.isError // Error itself and retryAction don't contribute to equality
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
