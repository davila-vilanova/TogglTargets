//
//  GoalProgress.swift
//  TogglTargets
//
//  Created by David Dávila on 13.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

/// GoalProgress 
class GoalProgress {
    // MARK: - Interface

    public var projectId: BindingTarget<Int64> { return _projectId.deoptionalizedBindingTarget }
    public var timeTarget: BindingTarget<TimeTarget>{ return _goal.deoptionalizedBindingTarget }
    public var report: BindingTarget<TwoPartTimeReport?>{ return _report.bindingTarget }
    public var runningEntry: BindingTarget<RunningEntry?>{ return _runningEntry.bindingTarget }
    public var startGoalDay: BindingTarget<DayComponents>{ return _startGoalDay.deoptionalizedBindingTarget }
    public var endGoalDay: BindingTarget<DayComponents>{ return _endGoalDay.deoptionalizedBindingTarget }
    public var startStrategyDay: BindingTarget<DayComponents>{ return _startStrategyDay.deoptionalizedBindingTarget }
    public var currentDate: BindingTarget<Date>{ return _currentDate.deoptionalizedBindingTarget }
    public var calendar: BindingTarget<Calendar>{ return _calendar.deoptionalizedBindingTarget }

    // MARK: - Outputs

    public lazy var timeGoal: SignalProducer<TimeInterval, NoError> = {
        return _goal.producer.skipNil().skipRepeats().map { TimeInterval.from(hours: $0.hoursTarget) }
    }()

    // Will be nil if start or end are invalid dates
    public lazy var totalWorkDays: SignalProducer<Int?, NoError> = {
        return SignalProducer.combineLatest(_goal.producer.skipNil().skipRepeats(),
                                            _startGoalDay.producer.skipNil().skipRepeats(),
                                            _endGoalDay.producer.skipNil().skipRepeats(),
                                            _calendar.producer.skipNil().skipRepeats())
            .map { (timeTarget, startGoalDay, endGoalDay, calendar) in
                return try? calendar.countWeekdaysMatching(timeTarget.workWeekdays, from: startGoalDay, to: endGoalDay)
        }
    }()

    // Will be nil if start or end are invalid dates
    public lazy var remainingWorkDays: SignalProducer<Int?, NoError> = {
        return SignalProducer.combineLatest(_goal.producer.skipNil().skipRepeats(),
                                            _startStrategyDay.producer.skipNil().skipRepeats(),
                                            _endGoalDay.producer.skipNil().skipRepeats(),
                                            _calendar.producer.skipNil().skipRepeats())
            .map { (timeTarget, startStrategyDay, endGoalDay, calendar) in
                return try? calendar.countWeekdaysMatching(timeTarget.workWeekdays, from: startStrategyDay, to: endGoalDay)
        }
    }()

    public lazy var strategyStartsToday: SignalProducer<Bool, NoError> = {
        return SignalProducer.combineLatest(_startStrategyDay.producer.skipNil().skipRepeats(),
                                            _currentDate.producer.skipNil().skipRepeats(),
                                            _calendar.producer.skipNil().skipRepeats())
            .map { (startStrategyDay, currentDate, calendar) in
                return calendar.dayComponents(from: currentDate) == startStrategyDay
        }
    }()

    public lazy var reportAvailable = _report.map { $0 != nil }

    public lazy var workedTime: SignalProducer<TimeInterval, NoError> = {
        return SignalProducer.combineLatest(_report.producer.skipRepeats(),
                                            strategyStartsToday.skipRepeats(),
                                            runningEntryTime.skipRepeats())
            .map { (reportOrNil, strategyStartsToday, runningEntryTime) -> TimeInterval in
                if strategyStartsToday {
                    return reportOrNil?.workedTimeUntilDayBeforeRequest ?? 0
                } else {
                    return (reportOrNil?.workedTime ?? 0) + runningEntryTime
                }
            }
    }()

    public lazy var remainingTimeToGoal: SignalProducer<TimeInterval, NoError>  = {
        return SignalProducer.combineLatest(timeGoal.skipRepeats(),
                                            workedTime.skipRepeats())
            .map { (timeGoal, workedTime) in
                return Double.maximum(timeGoal - workedTime, 0.0)
        }
    }()

    // dayBaseline will publish nil values when totalWorkDays itself returns nil
    public lazy var dayBaseline: SignalProducer<TimeInterval?, NoError> = {
        return SignalProducer.combineLatest(timeGoal.skipRepeats(),
                                            totalWorkDays.skipRepeats())
            .map { (timeGoal, totalWorkDays) -> TimeInterval? in
                guard let totalWorkDays = totalWorkDays else {
                    return nil
                }
                guard totalWorkDays > 0 else {
                    return 0
                }
                return timeGoal / TimeInterval(totalWorkDays)
        }
    }()


    // dayBaselineAdjustedToProgress will publish nil values when remainingWorkDays itself returns nil
    public lazy var dayBaselineAdjustedToProgress: SignalProducer<TimeInterval?, NoError> = {
        return SignalProducer.combineLatest(remainingWorkDays.skipRepeats(),
                                            remainingTimeToGoal.skipRepeats())
            .map { (remainingWorkDays, remainingTimeToGoal) -> TimeInterval? in
                guard let remainingWorkDays = remainingWorkDays else {
                    return nil
                }
                guard remainingWorkDays > 0 else {
                    return 0
                }
                return remainingTimeToGoal / Double(remainingWorkDays)
        }
    }()

    public lazy var feasibility: SignalProducer<GoalFeasibility?, NoError> =
        dayBaselineAdjustedToProgress.map {
            guard let baseline = $0 else {
                return nil
            }
            return GoalFeasibility.from(dayBaseline: baseline)
    }

    // dayBaselineDifferential will publish nil values if either dayBaseline or dayBaselineAdjustedToProgress are nil
    public lazy var dayBaselineDifferential: SignalProducer<Double?, NoError>  = {
        return SignalProducer.combineLatest(dayBaseline.skipRepeats(),
                                            dayBaselineAdjustedToProgress.skipRepeats())
            .map { (dayBaseline, dayBaselineAdjustedToProgress) -> Double? in
                guard let dayBaseline = dayBaseline else {
                    return nil
                }
                guard let dayBaselineAdjustedToProgress = dayBaselineAdjustedToProgress else {
                    return nil
                }
                assert(dayBaseline >= 0)
                return (dayBaselineAdjustedToProgress - dayBaseline) / dayBaseline
        }
    }()

    public lazy var timeWorkedToday: SignalProducer<TimeInterval, NoError>  = {
        return SignalProducer.combineLatest(_report.skipRepeats(),
                                            runningEntryTime.skipRepeats())
            .map { (report, runningEntryTime) in
                let workedTimeToday = report?.workedTimeOnDayOfRequest ?? 0
                return workedTimeToday + runningEntryTime
        }
    }()

    // remainingTimeToDayBaseline will publish nil values when either of this is true:
    // * today's date is not included in the period for which the target-reaching strategy is being calculated (there is no day baseline),
    // * dayBaselineAdjustedToProgress itself returns nil
    public lazy var remainingTimeToDayBaseline: SignalProducer<TimeInterval?, NoError> = {
        return SignalProducer.combineLatest(strategyStartsToday.skipRepeats(),
                                            dayBaselineAdjustedToProgress.skipRepeats(),
                                            timeWorkedToday.skipRepeats())
            .map { (strategyStartsToday, dayBaselineAdjustedToProgress, timeWorkedToday) -> TimeInterval? in
                guard strategyStartsToday else {
                    return nil
                }
                guard let dayBaselineAdjustedToProgress = dayBaselineAdjustedToProgress else {
                    return nil
                }
                return Double.maximum(dayBaselineAdjustedToProgress - timeWorkedToday, 0.0)
        }
    }()


    // MARK: - Backing input properties

    private let _projectId = MutableProperty<Int64?>(nil)
    private let _goal = MutableProperty<TimeTarget?>(nil)
    private let _report = MutableProperty<TwoPartTimeReport?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _startGoalDay = MutableProperty<DayComponents?>(nil)
    private let _endGoalDay = MutableProperty<DayComponents?>(nil)
    private let _startStrategyDay = MutableProperty<DayComponents?>(nil)
    private let _currentDate = MutableProperty<Date?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)


    // MARK: - Intermediates

    private lazy var runningEntryTime: SignalProducer<TimeInterval, NoError> = {
        return SignalProducer.combineLatest(_projectId.producer.skipNil().skipRepeats(),
                                            _runningEntry.skipRepeats(),
                                            _currentDate.producer.skipNil().skipRepeats())
            .map { (projectId, runningEntry, currentDate) in
                guard let runningEntry = runningEntry else {
                    return 0
                }
                guard projectId == runningEntry.projectId else {
                    return 0
                }
                return runningEntry.runningTime(at: currentDate)
        }
    }()
}

extension Calendar {
    func countWeekdaysMatching(_ weekday: Weekday, from: DayComponents, until: DayComponents) throws -> Int {
        return try countWeekdaysMatching([weekday], from: from, to: until)
    }

    func countWeekdaysMatching(_ weekdays: [Weekday], from start: DayComponents, to end: DayComponents) throws -> Int {
        var count = 0

        var matchComponents = Set<DateComponents>()
        for weekday in weekdays {
            matchComponents.insert(DateComponents(weekday: weekday.indexInGregorianCalendar))
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