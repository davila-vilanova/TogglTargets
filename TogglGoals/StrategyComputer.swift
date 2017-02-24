//
//  StrategyComputer.swift
//  TogglGoals
//
//  Created by David Davila on 23.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class StrategyComputer {
    private(set) var calendar: Calendar {
        didSet {
            // assert gregorian, toggl deals with gregorian only
        }
    }

    enum ComputationMode {
        case fromToday
        case fromNextWorkDay
    }

    var goal: TimeGoal? {
        didSet {
            // recompute if different
        }
    }
    var report: TimeReport?  {
        didSet {
            // recompute if different
        }
    }
    var month: Any? /* type TBD */ {
        didSet {
            // recompute if different
        }
    }

    var computationMode: ComputationMode = .fromToday {
        didSet {
            // recompute if different
        }
    }

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    var totalWorkdays: Int {
        // TODO
        return 0
    }

    var remainingFullWorkdays: Int {
        // TODO
        return 0
    }

    var availableRemainingHours: Int {
        // TODO
        return 0
    }

    var remainingHoursToGoal: Int {
        // TODO
        return 0
    }

    var monthProgress: Double {
        // TODO
        return 0.0
    }

    var goalCompletionProgress: Double {
        // TODO
        return 0.0
    }

    var dayBaseline: Double {
        // TODO
        return 0.0
    }

    var dayBaselineAdjustedToProgress: Double {
        // TODO
        return 0.0
    }

    var dayBaselineDifferential: Double {
        // TODO
        return 0.0
    }
}
