//
//  StrategyComputer.swift
//  TogglGoals
//
//  Created by David Davila on 23.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class StrategyComputer {
    let hourTimeInterval: TimeInterval = 3600

    private(set) var calendar: Calendar {
        didSet {
            assert(calendar.identifier == .iso8601)
        }
    }

    private var now: Date

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

    init(calendar: Calendar, now: Date) {
        self.calendar = calendar
        self.now = now
    }

    var totalWorkdays: Int {
        guard let goal = self.goal else {
            return 0
        }
        let c = calendar
        let first = c.firstDayOfMonth(for: now)
        let last = c.lastDayOfMonth(for: now)
        do {
            return try c.countWeekdaysMatching(goal.workWeekdays, from: first, to: last)
        } catch {
            return 0
        }
    }

    var remainingFullWorkdays: Int {
        guard let goal = self.goal else {
            return 0
        }
        let c = calendar
        let dayComponents: DayComponents

        switch (computationMode) {
        case .fromToday:
            dayComponents = c.dayComponents(from: now)
        case .fromNextWorkDay:
            do {
                try dayComponents = c.nextDayInMonth(for: now)
            } catch {
                return 0
            }
        }

        let last = c.lastDayOfMonth(for: now)
        do {
            return try c.countWeekdaysMatching(goal.workWeekdays, from: dayComponents, to: last)
        } catch {
            return 0
        }
    }

    var timeGoal: TimeInterval {
        guard let goal = self.goal else {
            return 0
        }
        return TimeInterval(goal.hoursPerMonth) * hourTimeInterval
    }

    var workedTime: TimeInterval {
        guard let report = self.report else {
            return 0
        }
        return report.workedTime
    }

    var remainingTimeToGoal: TimeInterval {
        return Double.maximum(timeGoal - workedTime, 0)
    }

    var dayBaseline: TimeInterval {
        let totalWorkdays = Double(self.totalWorkdays)
        guard totalWorkdays > 0 else {
            return 0
        }
        return timeGoal / totalWorkdays
    }

    var dayBaselineAdjustedToProgress: Double {
        let remainingFullWorkdays = Double(self.remainingFullWorkdays)
        guard remainingFullWorkdays > 0 else {
            return 0
        }
        return remainingTimeToGoal / remainingFullWorkdays
    }

    var dayBaselineDifferential: Double {
        guard dayBaseline > 0 else {
            return 0
        }
        return (dayBaselineAdjustedToProgress - dayBaseline) / dayBaseline
    }
}

extension Weekday {
    var dayIndex: Int {
        return rawValue + 1
    }
}

extension Calendar {
    func countWeekdaysMatching(_ weekday: Weekday, from: DayComponents, until: DayComponents) throws -> Int {
        return try countWeekdaysMatching([weekday], from: from, to: until)
    }

    func countWeekdaysMatching(_ weekdays: [Weekday], from start: DayComponents, to end: DayComponents) throws -> Int {
        var count = 0

        var matchComponents = Set<DateComponents>()
        for weekday in weekdays {
            matchComponents.insert(DateComponents(weekday: weekday.dayIndex))
        }

        let oneDayIncrement = DateComponents(day: 1)
        var testeeDate = try date(from: start)
        let endDate = try date(from: end)

        while testeeDate < endDate || isDate(testeeDate, inSameDayAs: endDate) {
            for comps in matchComponents {
                if date(testeeDate, matchesComponents: comps) {
                    count += 1
                    break
                }
            }

            var nextDate: Date;
            repeat {
                nextDate = date(byAdding: oneDayIncrement, to: testeeDate)!
            } while isDate(nextDate, inSameDayAs: testeeDate)

            testeeDate = nextDate
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
    func countWeekdaysMatching(_ selection: WeekdaySelection, from: DayComponents, to: DayComponents) throws -> Int {
        return try countWeekdaysMatching(selection.selectedWeekdays, from: from, to: to)
    }
}
