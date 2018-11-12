//
//  ProgressToTimeTarget.swift
//  TogglTargets
//
//  Created by David Dávila on 13.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

/// Calculates the progress made towards a given time target based on a reference date (such as the current date),
/// the time period that frames the target, the day to start the calculation from and the time worked so far.
class ProgressToTimeTarget {

    // MARK: - Inputs

    /// The ID of the project associated with the time target towards which to calculate progress
    // TODO: Remove as redundant with timeTarget.projectId 
    public var projectId: BindingTarget<ProjectID> { return _projectId.deoptionalizedBindingTarget }

    /// The time target towards which to calculate progress
    public var timeTarget: BindingTarget<TimeTarget> { return _timeTarget.deoptionalizedBindingTarget }

    /// The associated worked time report. `nil` reports are interpreted as zero worked time.
    public var report: BindingTarget<TwoPartTimeReport?> { return _report.bindingTarget }

    /// The currently running entry, if any. If the entry's project ID matches the ID of the project whose time target
    /// progress is being calculated, the entry's worked time will count towards the progress.
    public var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }

    /// The first day of the period in which progress is being calculated
    public var startDay: BindingTarget<DayComponents> { return _startDay.deoptionalizedBindingTarget }

    /// The last day of the period in which progress is being calculated
    public var endDay: BindingTarget<DayComponents> { return _endDay.deoptionalizedBindingTarget }

    /// The day from which the 'strategy', that is, the amount of time to work per day given the remaining work days,
    /// will be calculated.
    public var startStrategyDay: BindingTarget<DayComponents> { return _startStrategyDay.deoptionalizedBindingTarget }
    
    /// The reference date to use to calculate progress
    public var currentDate: BindingTarget<Date> { return _currentDate.deoptionalizedBindingTarget }
    
    /// The calendar to use to perform any computations that require one
    public var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }

    // MARK: - Outputs

    /// The time target in seconds
    public lazy var targetTime: SignalProducer<TimeInterval, NoError> = {
        return _timeTarget.producer.skipNil().skipRepeats().map { TimeInterval.from(hours: $0.hoursTarget) }
    }()

    /// The total work days in the current period given the days of the week that are available to work according to
    /// the current time target. 
    public lazy var totalWorkDays: SignalProducer<Int?, NoError> = {
        return SignalProducer.combineLatest(_timeTarget.producer.skipNil().skipRepeats(),
                                            _startDay.producer.skipNil().skipRepeats(),
                                            _endDay.producer.skipNil().skipRepeats(),
                                            _calendar.producer.skipNil().skipRepeats())
            .map { (timeTarget, startDay, endDay, calendar) in
                return calendar.countWeekdaysMatching(timeTarget.workWeekdays, from: startDay, to: endDay)
        }
    }()

    /// The amount of work days that remain in the current time period based to the days of the week that are
    /// available to work according to the current time target and the day from which to calculate the strategy.
    public lazy var remainingWorkDays: SignalProducer<Int?, NoError> = {
        return SignalProducer.combineLatest(_timeTarget.producer.skipNil().skipRepeats(),
                                            _startStrategyDay.producer.skipNil().skipRepeats(),
                                            _endDay.producer.skipNil().skipRepeats(),
                                            _calendar.producer.skipNil().skipRepeats())
            .map { (timeTarget, startStrategyDay, endDay, calendar) in
                return calendar.countWeekdaysMatching(timeTarget.workWeekdays, from: startStrategyDay, to: endDay)
        }
    }()

    /// Whether the day from which the strategy should be calculated matches the day that contains the reference date
    /// `currentDate`, as interpreted in the current calendar's time zone.
    public lazy var strategyStartsToday: SignalProducer<Bool, NoError> = {
        return SignalProducer.combineLatest(_startStrategyDay.producer.skipNil().skipRepeats(),
                                            _currentDate.producer.skipNil().skipRepeats(),
                                            _calendar.producer.skipNil().skipRepeats())
            .map { (startStrategyDay, currentDate, calendar) in
                return calendar.dayComponents(from: currentDate) == startStrategyDay
        }
    }()

    /// Whether a time report is available
    // TODO: if nil time reports are interpreted as zero worked time, this property may not make sense.
    // TODO: if this property does make sense, check whether the report's project ID matches the active project ID.
    public lazy var reportAvailable = _report.map { $0 != nil }

    /// The amount of time worked for the project corresponding to the current time target. Includes the time worked
    /// in the reference date if `strategyStartsToday` is currently true.
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

    /// The amount of time left to reach the current time target.
    /// This is calculated differently depending on whether today (or, more generally, the day represented by the 
    /// reference date) is the day from which to calculate the strategy from. If that is the case, the time worked today
    /// is not subtracted from the remaining time to work. Instead, that time will count against the time that must be
    /// worked today. If the strategy starts in a later day, the time worked today is subtracted.
    public lazy var remainingTimeToTarget: SignalProducer<TimeInterval, NoError>  = {
        return SignalProducer.combineLatest(targetTime.skipRepeats(),
                                            workedTime.skipRepeats())
            .map { (targetTime, workedTime) in
                return Double.maximum(targetTime - workedTime, 0.0)
        }
    }()

    // dayBaseline will publish nil values when totalWorkDays itself returns nil
    public lazy var dayBaseline: SignalProducer<TimeInterval?, NoError> = {
        return SignalProducer.combineLatest(targetTime.skipRepeats(),
                                            totalWorkDays.skipRepeats())
            .map { (targetTime, totalWorkDays) -> TimeInterval? in
                guard let totalWorkDays = totalWorkDays else {
                    return nil
                }
                guard totalWorkDays > 0 else {
                    return 0
                }
                return targetTime / TimeInterval(totalWorkDays)
        }
    }()

    // dayBaselineAdjustedToProgress will publish nil values when remainingWorkDays itself returns nil
    public lazy var dayBaselineAdjustedToProgress: SignalProducer<TimeInterval?, NoError> = {
        return SignalProducer.combineLatest(remainingWorkDays.skipRepeats(),
                                            remainingTimeToTarget.skipRepeats())
            .map { (remainingWorkDays, remainingTimeToTarget) -> TimeInterval? in
                guard let remainingWorkDays = remainingWorkDays else {
                    return nil
                }
                guard remainingWorkDays > 0 else {
                    return 0
                }
                return remainingTimeToTarget / Double(remainingWorkDays)
        }
    }()

    public lazy var feasibility: SignalProducer<TargetFeasibility?, NoError> =
        dayBaselineAdjustedToProgress.map {
            guard let baseline = $0 else {
                return nil
            }
            return TargetFeasibility.from(dayBaseline: baseline)
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
    // * today's date is not included in the period for which the target-reaching strategy is being calculated
    //   (there is no day baseline),
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
    private let _timeTarget = MutableProperty<TimeTarget?>(nil)
    private let _report = MutableProperty<TwoPartTimeReport?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _startDay = MutableProperty<DayComponents?>(nil)
    private let _endDay = MutableProperty<DayComponents?>(nil)
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
    func countWeekdaysMatching(_ weekday: Weekday, from: DayComponents, until: DayComponents) -> Int {
        return countWeekdaysMatching([weekday], from: from, to: until)
    }

    func countWeekdaysMatching(_ weekdays: [Weekday], from start: DayComponents, to end: DayComponents) -> Int {
        var count = 0

        guard var testeeDate = date(from: start),
            let endDate = date(from: end) else {
                return count
        }

        var matchComponents = Set<DateComponents>()
        for weekday in weekdays {
            matchComponents.insert(DateComponents(weekday: weekday.indexInGregorianCalendar))
        }

        let oneDayIncrement = DateComponents(day: 1)

        while testeeDate < endDate || isDate(testeeDate, inSameDayAs: endDate) { // TODO !isLaterDay
            for comps in matchComponents {
                if date(testeeDate, matchesComponents: comps) {
                    count += 1
                    break
                }
            }

            var nextDate: Date
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
    // swiftlint:disable:next identifier_name
    func countWeekdaysMatching(_ selection: WeekdaySelection, from: DayComponents, to: DayComponents) -> Int {
        return countWeekdaysMatching(selection.selectedWeekdays, from: from, to: to)
    }
}
