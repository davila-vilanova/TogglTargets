//
//  Goal.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

typealias HoursTargetType = Int

struct Goal {
    let projectId: Int64
    var hoursTarget: HoursTargetType
    var workWeekdays: WeekdaySelection

    init(for projectId: Int64, hoursTarget: HoursTargetType, workWeekdays: WeekdaySelection) {
        self.projectId = projectId
        self.hoursTarget = hoursTarget
        self.workWeekdays = workWeekdays
    }
}

extension Goal: Equatable {
    static func ==(lhs: Goal, rhs: Goal) -> Bool {
        return lhs.projectId == rhs.projectId
            && lhs.hoursTarget == rhs.hoursTarget
            && lhs.workWeekdays == rhs.workWeekdays
    }
}

extension Goal: Comparable {
    static func <(lhs: Goal, rhs: Goal) -> Bool {
        return lhs.hoursTarget < rhs.hoursTarget
    }
}

extension Goal {
    static var empty: Goal {
        return Goal(for: 0, hoursTarget: 0, workWeekdays: WeekdaySelection.empty)
    }

    static func createDefault(for projectId: ProjectID) -> Goal {
        return Goal(for: projectId, hoursTarget: 10, workWeekdays: WeekdaySelection.exceptWeekend)
    }
}

extension Goal: CustomDebugStringConvertible {
    var debugDescription: String {
        get {
            return "Goal(for: \(projectId), hoursTarget: \(hoursTarget), workWeekdays: \(workWeekdays))"
        }
    }
}
