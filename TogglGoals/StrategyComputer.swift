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
        let maybeTomorrow = c.nextDayInMonth(for: now)
        guard let tomorrow = maybeTomorrow else {
            return 0
        }
        let last = c.lastDayOfMonth(for: now)
        do {
            return try c.countWeekdaysMatching(goal.workWeekdays, from: tomorrow, to: last)
        } catch {
            return 0
        }
    }


    var hoursTarget: Int {
        guard let goal = self.goal else {
            return 0
        }
        return goal.hoursPerMonth
    }

    var workedHours: Double {
        guard let report = self.report else {
            return 0
        }
        return report.workedTime
    }

    var remainingHoursToGoal: Double {
        guard let goal = self.goal else {
            return 0
        }
        return Double(goal.hoursPerMonth) - workedHours
    }

    var monthProgress: Double {
        guard totalWorkdays > 0 else {
            return 1
        }
        guard remainingFullWorkdays <= totalWorkdays else {
            return 1
        }
        return Double(remainingFullWorkdays) / Double(totalWorkdays)
    }

    var goalCompletionProgress: Double {
        let hoursTarget = Double(self.hoursTarget)
        guard hoursTarget > 0 else {
            return 1
        }
        guard workedHours <= hoursTarget else {
            return 1
        }
        return workedHours / hoursTarget
    }

    var dayBaseline: Double {
        let hoursTarget = Double(self.hoursTarget)
        let totalWorkdays = Double(self.totalWorkdays)
        guard totalWorkdays > 0 else {
            return 0
        }
        return hoursTarget / totalWorkdays
    }

    var dayBaselineAdjustedToProgress: Double {
        let hoursTarget = Double(self.hoursTarget)
        let remainingFullWorkdays = Double(self.remainingFullWorkdays)
        guard remainingFullWorkdays > 0 else {
            return 0
        }
        return hoursTarget / remainingFullWorkdays
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
    func countWeekdaysMatching(_ weekday: Weekday, from: DateComponents, until: DateComponents) throws -> Int {
        return try countWeekdaysMatching([weekday], from: from, to: until)
    }

    enum CountWeekdaysError: Error {
        case missingDateComponents
        case invalidDateComponents
    }

    func countWeekdaysMatching(_ weekdays: [Weekday], from start: DateComponents, to end: DateComponents) throws -> Int {
        let requiredComponents: Set<Calendar.Component> = [.year, .month, .day]
        let irrelevantComponents: Set<Calendar.Component> = [.hour, .minute, .second, .nanosecond, .era, .quarter, .weekOfMonth, .weekOfYear, .weekday, .weekdayOrdinal, .yearForWeekOfYear]

        for comp in requiredComponents {
            guard start.value(for: comp) != nil, end.value(for: comp) != nil else {
                throw CountWeekdaysError.missingDateComponents
            }
        }

        var sanitizedStart = start
        var sanitizedEnd = end

        for comp in irrelevantComponents {
            sanitizedStart.setValue(nil, for: comp)
            sanitizedEnd.setValue(nil, for: comp)
        }

        var count = 0

        var matchComponents = Set<DateComponents>()
        for weekday in weekdays {
            matchComponents.insert(DateComponents(weekday: weekday.dayIndex))
        }

        let oneDayIncrement = DateComponents(day: 1)
        var stop = false
        guard var eachDate = date(from: sanitizedStart), let endDate = date(from: sanitizedEnd) else {
            throw CountWeekdaysError.invalidDateComponents
        }

        while !stop {
            for comps in matchComponents {
                if date(eachDate, matchesComponents: comps) {
                    count += 1
                    break
                }
            }
            eachDate = date(byAdding: oneDayIncrement, to: eachDate)!
            if eachDate > endDate && !isDate(eachDate, inSameDayAs: endDate) {
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
    func countWeekdaysMatching(_ selection: WeekdaySelection, from: DateComponents, to: DateComponents) throws -> Int {
        return try countWeekdaysMatching(selection.selectedWeekdays, from: from, to: to)
    }
}
