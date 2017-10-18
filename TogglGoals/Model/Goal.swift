//
//  Goal.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct Goal {
    // TODO: move here the start and end days
    let projectId: Int64
    var hoursPerMonth: Int
    var workWeekdays: WeekdaySelection

    init(forProjectId projectId: Int64, hoursPerMonth: Int, workWeekdays: WeekdaySelection) {
        self.projectId = projectId
        self.hoursPerMonth = hoursPerMonth
        self.workWeekdays = workWeekdays
    }
}

extension Goal: Equatable {
    static func ==(lhs: Goal, rhs: Goal) -> Bool {
        return lhs.projectId == rhs.projectId
            && lhs.hoursPerMonth == rhs.hoursPerMonth
            && lhs.workWeekdays == rhs.workWeekdays
    }
}

extension Goal: Comparable {
    static func <(lhs: Goal, rhs: Goal) -> Bool {
        return lhs.hoursPerMonth < rhs.hoursPerMonth
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
            return "Goal(forProjectId: \(projectId), hoursPerMonth: \(hoursPerMonth), workWeekdays: \(workWeekdays))"
        }
    }
}
