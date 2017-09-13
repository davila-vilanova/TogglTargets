//
//  GoalProgress.swift
//  TogglGoals
//
//  Created by David Dávila on 13.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

// TODO: deal with inconsistency errors, calculation errors and out-of-sync values when an input is nil
class GoalProgress {

    // MARK: - Inputs

    public let projectId = MutableProperty<Int64?>(nil)
    public let goal = MutableProperty<Goal?>(nil)
    public let report = MutableProperty<TwoPartTimeReport?>(nil)
    public let runningEntry = MutableProperty<RunningEntry?>(nil)
    public var startGoalDay = MutableProperty<DayComponents?>(nil)
    public var endGoalDay = MutableProperty<DayComponents?>(nil)
    public var startStrategyDay = MutableProperty<DayComponents?>(nil)
    public let now = MutableProperty<Date?>(nil)
    public let calendar = MutableProperty<Calendar?>(nil)


    // MARK: - Intermediates

    private let strategyStartsToday = MutableProperty<Bool?>(nil)
    private let runningTime = MutableProperty<TimeInterval>(0.0)

    // MARK: - Outputs

    public let timeGoal = MutableProperty<TimeInterval>(0.0)
    public let totalWorkDays = MutableProperty<Int?>(nil)
    public let remainingWorkDays = MutableProperty<Int?>(nil)
    public let workedTime = MutableProperty<TimeInterval?>(nil)
    public let remainingTimeToGoal = MutableProperty<TimeInterval?>(nil)
    public let dayBaseline = MutableProperty<TimeInterval?>(nil)
    public let dayBaselineAdjustedToProgress = MutableProperty<TimeInterval?>(nil)
    public let dayBaselineDifferential = MutableProperty<Double?>(nil)
    public let timeWorkedToday = MutableProperty<TimeInterval?>(nil)
    public let remainingTimeToDayBaseline = MutableProperty<TimeInterval?>(nil)


    // MARK: - Calculations

    init() {
        setupSignals()
    }

    private func setupSignals() {
        strategyStartsToday <~ SignalProducer.combineLatest(startStrategyDay.producer.skipNil(),
                                                            now.producer.skipNil(),
                                                            calendar.producer.skipNil())
            .map { (startStrategyDay, now, calendar) in
                return calendar.dayComponents(from: now) == startStrategyDay
        }

        runningTime <~ SignalProducer.combineLatest(projectId.producer.skipNil(),
                                                    runningEntry.producer.skipNil(),
                                                    now.producer.skipNil())
            .map { (projectId, runningEntry, now) in
                guard projectId == runningEntry.projectId else {
                    return 0
                }
                return now.timeIntervalSince(runningEntry.start)
        }

        timeGoal <~ goal.producer.skipNil().map { TimeInterval($0.hoursPerMonth) * TimeInterval(3600) }

        totalWorkDays <~ SignalProducer.combineLatest(goal.producer.skipNil(),
                                                      startGoalDay.producer.skipNil(),
                                                      endGoalDay.producer.skipNil(),
                                                      calendar.producer.skipNil())
            .map { (goal, startGoalDay, endGoalDay, calendar) -> Int? in
                return try? calendar.countWeekdaysMatching(goal.workWeekdays, from: startGoalDay, to: endGoalDay)
        }

        remainingWorkDays <~ SignalProducer.combineLatest(goal.producer.skipNil(),
                                                          startStrategyDay.producer.skipNil(),
                                                          endGoalDay.producer.skipNil(),
                                                          calendar.producer.skipNil())
            .map { (goal, startStrategyDay, endGoalDay, calendar) -> Int? in
                return try? calendar.countWeekdaysMatching(goal.workWeekdays, from: startStrategyDay, to: endGoalDay)
        }

        workedTime <~ SignalProducer.combineLatest(report.producer.skipNil(),
                                                   strategyStartsToday.producer.skipNil(),
                                                   runningTime.producer)
            .map { (report, strategyStartsToday, runningTime) -> TimeInterval in
                return strategyStartsToday ? report.workedTimeUntilYesterday : report.workedTime + runningTime
        }

        remainingTimeToGoal <~ SignalProducer.combineLatest(timeGoal,
                                                            workedTime.producer.skipNil())
            .map { (timeGoal, workedTime) in
                return Double.maximum(timeGoal - workedTime, 0.0)
        }

        dayBaseline <~ SignalProducer.combineLatest(timeGoal,
                                                    totalWorkDays.producer.skipNil())
            .map { (timeGoal, totalWorkDays) -> Double in
                guard totalWorkDays > 0 else {
                    return 0
                }
                return timeGoal / Double(totalWorkDays)
        }

        dayBaselineAdjustedToProgress <~ SignalProducer.combineLatest(remainingWorkDays.producer.skipNil(),
                                                                      remainingTimeToGoal.producer.skipNil())
            .map { (remainingWorkDays, remainingTimeToGoal) -> Double in
                guard remainingWorkDays > 0 else {
                    return 0
                }
                return remainingTimeToGoal / Double(remainingWorkDays)
        }

        dayBaselineDifferential <~ SignalProducer.combineLatest(dayBaseline.producer.skipNil(),
                                                                dayBaselineAdjustedToProgress.producer.skipNil())
            .map { (dayBaseline, dayBaselineAdjustedToProgress) -> Double in
                guard dayBaseline > 0 else {
                    return 0
                }
                return (dayBaselineAdjustedToProgress - dayBaseline) / dayBaseline
        }

        timeWorkedToday <~ SignalProducer.combineLatest(report.producer.skipNil(),
                                                        runningTime.producer)
            .map { (report, runningTime) in
                return report.workedTimeToday + runningTime
        }

        remainingTimeToDayBaseline <~ SignalProducer.combineLatest(strategyStartsToday.producer.skipNil(),
                                                                   dayBaselineAdjustedToProgress.producer.skipNil(),
                                                                   timeWorkedToday.producer.skipNil())
            .map { (strategyStartsToday, dayBaselineAdjustedToProgress, timeWorkedToday) -> TimeInterval? in
                guard strategyStartsToday else {
                    return nil
                }
                return Double.maximum(dayBaselineAdjustedToProgress - timeWorkedToday, 0.0)
        }
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
