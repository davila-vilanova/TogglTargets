//
//  Goal.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct Goal {
    let projectId: Int64
    var hoursTarget: Int
    var workWeekdays: WeekdaySelection

    // TODO: rename argument labels
    init(forProjectId projectId: Int64, hoursPerMonth: Int, workWeekdays: WeekdaySelection) {
        self.projectId = projectId
        self.hoursTarget = hoursPerMonth
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
        return Goal(forProjectId: 0, hoursPerMonth: 0, workWeekdays: WeekdaySelection.empty)
    }
}

extension Goal: CustomDebugStringConvertible {
    var debugDescription: String {
        get {
            return "Goal(forProjectId: \(projectId), hoursPerMonth: \(hoursTarget), workWeekdays: \(workWeekdays))"
        }
    }
}
