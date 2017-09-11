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

    var startPeriodDay: DayComponents?
    var startStrategyDay: DayComponents?
    var endPeriodDay: DayComponents?
    var now: Date?

    var goal: TimeGoal? {
        didSet {
            // recompute if different
        }
    }

    var report: TwoPartTimeReport?  {
        didSet {
            // recompute if different
        }
    }

    var runningEntry: RunningEntry?

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    var projectId: Int64?

    private var totalWorkdays: Int {
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

    private var remainingWorkdays: Int {
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

    var isComputingStrategyFromToday: Bool {
        guard let startStrategyDay = self.startStrategyDay else {
            return false
        }
        return startStrategyDay == calendar.dayComponents(from: Date())
    }

    private var workedTime: TimeInterval {
        guard let report = self.report else {
            return 0
        }
        if isComputingStrategyFromToday { // today
            return report.workedTimeUntilYesterday
        } else {
            return report.workedTime + runningTime
        }
    }

    private var workedTimeToday: TimeInterval {
        guard let report = self.report else {
            return 0
        }
        return report.workedTimeToday + runningTime
    }

    private var remainingTimeToDayBaselineToday: TimeInterval? {
        if !isComputingStrategyFromToday {
            return nil
        }
        let remaining = dayBaselineAdjustedToProgress - workedTimeToday
        if remaining < 0 {
            return 0
        } else {
            return remaining
        }
    }
    
    private var runningEntryBelongsToProject: Bool {
        guard let runningEntry = self.runningEntry,
            let projectId = self.projectId else {
            return false
        }
        return runningEntry.projectId == projectId
    }

    private var runningTime: TimeInterval {
        guard let runningEntry = self.runningEntry,
            runningEntryBelongsToProject,
            let now = self.now else {
                return 0
        }
        return now.timeIntervalSince(runningEntry.start)
    }
    
    var dayProgress: DayProgress {
        return DayProgress(workedTimeToday: workedTimeToday, remainingTimeToDayBaselineToday: remainingTimeToDayBaselineToday)
    }

    private var remainingTimeToGoal: TimeInterval {
        return Double.maximum(timeGoal - workedTime, 0)
    }

    var goalProgress: GoalProgress {
        return GoalProgress(totalWorkdays: totalWorkdays, remainingWorkdays: remainingWorkdays, timeGoal: timeGoal, workedTime: workedTime, remainingTimeToGoal: remainingTimeToGoal)
    }
    
    private var dayBaseline: TimeInterval {
        let totalWorkdays = Double(self.totalWorkdays)
        guard totalWorkdays > 0 else {
            return 0
        }
        return timeGoal / totalWorkdays
    }

    private var dayBaselineAdjustedToProgress: Double {
        let remainingFullWorkdays = Double(self.remainingWorkdays)
        guard remainingFullWorkdays > 0 else {
            return 0
        }
        return remainingTimeToGoal / remainingFullWorkdays
    }

    private var dayBaselineDifferential: Double {
        guard dayBaseline > 0 else {
            return 0
        }
        return (dayBaselineAdjustedToProgress - dayBaseline) / dayBaseline
    }
    
    var goalStrategy: GoalStrategy {
        return GoalStrategy(timeGoal: timeGoal, dayBaseline: dayBaseline, dayBaselineAdjustedToProgress: dayBaselineAdjustedToProgress, dayBaselineDifferential: dayBaselineDifferential)
    }
}

struct GoalProgress {
    let totalWorkdays: Int
    let remainingWorkdays: Int
    let timeGoal: TimeInterval
    let workedTime: TimeInterval
    let remainingTimeToGoal: TimeInterval
}

struct GoalStrategy {
    let timeGoal: TimeInterval
    let dayBaseline: TimeInterval
    let dayBaselineAdjustedToProgress: Double
    let dayBaselineDifferential: Double
}

struct DayProgress {
    let workedTimeToday: TimeInterval
    var remainingTimeToDayBaselineToday: TimeInterval?
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

        while testeeDate < endDate || isDate(testeeDate, inSameDayAs: endDate) { // TODO !isLaterDay
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
