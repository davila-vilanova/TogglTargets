//
//  TimeTarget.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

typealias HoursTargetType = Int

/// Represents the amount of time that a user wishes to have worked in a given project at the end of a time period
/// together with related data such as the days of the week in which the user intends to work in the project.
struct TimeTarget {

    /// The ID of the project associated with this target.
    let projectId: ProjectID

    /// The amount of hours which this target represents.
    var hoursTarget: HoursTargetType

    /// The days of the week in which the user intends to work in the project associated with this target.
    var workWeekdays: WeekdaySelection

    init(for projectId: ProjectID, hoursTarget: HoursTargetType, workWeekdays: WeekdaySelection) {
        self.projectId = projectId
        self.hoursTarget = hoursTarget
        self.workWeekdays = workWeekdays
    }
}

extension TimeTarget: Equatable {
    static func == (lhs: TimeTarget, rhs: TimeTarget) -> Bool {
        return lhs.projectId == rhs.projectId
            && lhs.hoursTarget == rhs.hoursTarget
            && lhs.workWeekdays == rhs.workWeekdays
    }
}

extension TimeTarget: Comparable {
    /// A target A is smaller than target B only if A represents a smaller number of hours than B.
    static func < (lhs: TimeTarget, rhs: TimeTarget) -> Bool {
        return lhs.hoursTarget < rhs.hoursTarget
    }
}

extension TimeTarget {
    /// Each invocation returns an empty target: zero hours, no workdays selected, zeroed project ID.
    static var empty: TimeTarget {
        return TimeTarget(for: 0, hoursTarget: 0, workWeekdays: WeekdaySelection.empty)
    }

    /// Creates a target with default values for the provided project ID.
    ///
    /// - parameters:
    ///   - projectId: The ID of the project associated with this target.
    ///
    /// - returns: A newly created target for the provided project ID with default work time target and default
    ///            weekdays selected.
    static func createDefault(for projectId: ProjectID) -> TimeTarget {
        return TimeTarget(for: projectId, hoursTarget: 10, workWeekdays: WeekdaySelection.exceptWeekend)
    }
}

extension TimeTarget: CustomDebugStringConvertible {
    var debugDescription: String {
        return "TimeTarget(for: \(projectId), hoursTarget: \(hoursTarget), workWeekdays: \(workWeekdays))"
    }
}
