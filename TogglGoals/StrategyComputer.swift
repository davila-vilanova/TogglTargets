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

    var startPeriodDay: DayComponents? {
        guard let report = self.report else {
            return nil
        }
        return report.since
    }

    var startStrategyDay: DayComponents?

    var endPeriodDay: DayComponents? {
        guard let report = self.report else {
            return nil
        }
        return report.until
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

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    var totalWorkdays: Int {
        guard let goal = self.goal,
            let start = self.startPeriodDay,
            let end = self.endPeriodDay
            else {
                return 0
        }

        let c = calendar
        do {
            return try c.countWeekdaysMatching(goal.workWeekdays, from: start, to: end)
        } catch {
            return 0
        }
    }

    var remainingWorkdays: Int {
        guard let goal = self.goal,
            let start = self.startStrategyDay,
            let end = self.endPeriodDay else {
                return 0
        }

        let c = calendar
        do {
            return try c.countWeekdaysMatching(goal.workWeekdays, from: start, to: end)
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
        let remainingFullWorkdays = Double(self.remainingWorkdays)
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
