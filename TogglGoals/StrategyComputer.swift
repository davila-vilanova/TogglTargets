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
            assert(calendar.identifier == .iso8601)
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

    var computationMode: ComputationMode = .fromToday {
        didSet {
            // recompute if different
        }
    }

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    var totalWorkdays: Int {
        guard let goal = self.goal else {
            return 0
        }
        let c = calendar
        let now = Date() // TODO: "global now, tic tac"
        let first = c.firstDayOfMonth(for: now)
        let last = c.lastDayOfMonth(for: now)
        return c.countWeekdaysMatching(goal.workWeekdays, from: first, to: last)
    }

    var remainingFullWorkdays: Int {
        guard let goal = self.goal else {
            return 0
        }
        let c = calendar
        let now = Date()
        let maybeTomorrow = c.nextDayInMonth(for: now)
        guard let tomorrow = maybeTomorrow else {
            return 0
        }
        let last = c.lastDayOfMonth(for: now)
        return c.countWeekdaysMatching(goal.workWeekdays, from: tomorrow, to: last)
    }


    var hoursTarget: Int {
        // TODO
        return 0
    }

    var workedHours: Int {
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

extension Weekday {
    func dayIndex(for calendar: Calendar) -> Int {
        let sum = calendar.firstWeekday + rawValue
        let maxIndexBaseOne = Weekday.allDaysOrdered.last!.rawValue + 1
        return sum > maxIndexBaseOne ? sum - maxIndexBaseOne : sum
    }
}

extension Calendar {
    func countWeekdaysMatching(_ weekday: Weekday, from: DateComponents, until: DateComponents) -> Int {
        return countWeekdaysMatching([weekday], from: from, to: until)
    }

    func countWeekdaysMatching(_ weekdays: [Weekday], from start: DateComponents, to end: DateComponents) -> Int {
        var count = 0

        var matchComponents = Set<DateComponents>()
        for weekday in weekdays {
            matchComponents.insert(DateComponents(weekday: weekday.dayIndex(for: self)))
        }

        let oneDayIncrement = DateComponents(day: 1)
        var stop = false
        var eachDate = date(from: start)!
        let endDate = date(from: end)!

        while !stop {
            for comps in matchComponents {
                if date(eachDate, matchesComponents: comps) {
                    count += 1
                    break
                }
            }
            eachDate = date(byAdding: oneDayIncrement, to: eachDate)!
            if eachDate > endDate {
                stop = true
            }
        }

        return count
    }
}

extension WeekdaySelection {
    var selectedWeekdays: [Weekday] {
        var retval = [Weekday]()
        for day in Weekday.allDays {
            if isSelected(day) {
                retval.append(day)
            }
        }
        return retval
    }
}

extension Calendar {
    func countWeekdaysMatching(_ selection: WeekdaySelection, from: DateComponents, to: DateComponents) -> Int {
        return countWeekdaysMatching(selection.selectedWeekdays, from: from, to: to)
    }
}
