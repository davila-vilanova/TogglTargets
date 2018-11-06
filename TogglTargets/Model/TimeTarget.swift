//
//  TimeTarget.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

typealias HoursTargetType = Int

struct TimeTarget {
    let projectId: Int64
    var hoursTarget: HoursTargetType
    var workWeekdays: WeekdaySelection

    init(for projectId: Int64, hoursTarget: HoursTargetType, workWeekdays: WeekdaySelection) {
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
    static func < (lhs: TimeTarget, rhs: TimeTarget) -> Bool {
        return lhs.hoursTarget < rhs.hoursTarget
    }
}

extension TimeTarget {
    static var empty: TimeTarget {
        return TimeTarget(for: 0, hoursTarget: 0, workWeekdays: WeekdaySelection.empty)
    }

    static func createDefault(for projectId: ProjectID) -> TimeTarget {
        return TimeTarget(for: projectId, hoursTarget: 10, workWeekdays: WeekdaySelection.exceptWeekend)
    }
}

extension TimeTarget: CustomDebugStringConvertible {
    var debugDescription: String {
        return "TimeTarget(for: \(projectId), hoursTarget: \(hoursTarget), workWeekdays: \(workWeekdays))"
    }
}
