//
//  ProgressToTimeTarget.swift
//  TogglTargets
//
//  Created by David Dávila on 13.09.17.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
    // TODO: for non nil reports, check that reference date is coherent with this instance's reference date
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
    // TODO: rename to reference date
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
    public lazy var totalWorkDays: SignalProducer<Int, NoError> = {
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
    public lazy var remainingWorkDays: SignalProducer<Int, NoError> = {
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

    /// The amount of time one would have to work each work day through the period to achieve the current time target.
    public lazy var dayBaseline: SignalProducer<TimeInterval, NoError> = {
        return SignalProducer.combineLatest(targetTime.skipRepeats(),
                                            totalWorkDays.skipRepeats())
            .map { (targetTime, totalWorkDays) -> TimeInterval in
                guard totalWorkDays > 0 else {
                    return 0
                }
                return targetTime / TimeInterval(totalWorkDays)
        }
    }()

    /// The amount of time one would have to work each work day from `startStrategyDay` until the end of the period
    /// to achieve the current time target, given the current progress.
    public lazy var dayBaselineAdjustedToProgress: SignalProducer<TimeInterval, NoError> = {
        return SignalProducer.combineLatest(remainingWorkDays.skipRepeats(),
                                            remainingTimeToTarget.skipRepeats())
            .map { (remainingWorkDays, remainingTimeToTarget) -> TimeInterval in
                guard remainingWorkDays > 0 else {
                    return 0
                }
                return remainingTimeToTarget / Double(remainingWorkDays)
        }
    }()

    /// The feasibility of working `dayBaselineAdjustedToProgress`.
    public lazy var feasibility: SignalProducer<TargetFeasibility, NoError> =
        dayBaselineAdjustedToProgress.map(TargetFeasibility.from)

    /// Calculated based on `dayBaseline` and `dayBaselineAccordingToProgress`.
    public lazy var dayBaselineDifferential: SignalProducer<Double, NoError>  = {
        return SignalProducer.combineLatest(dayBaseline.skipRepeats(),
                                            dayBaselineAdjustedToProgress.skipRepeats())
            .map { (dayBaseline, dayBaselineAdjustedToProgress) -> Double in
                assert(dayBaseline >= 0)
                return (dayBaselineAdjustedToProgress - dayBaseline) / dayBaseline
        }
    }()

    /// The amount of time worked on the reference date. Calculated by combining the relevant part of the report and the
    /// running time entry.
    public lazy var timeWorkedToday: SignalProducer<TimeInterval, NoError>  = {
        return SignalProducer.combineLatest(_report.skipRepeats(),
                                            runningEntryTime.skipRepeats())
            .map { (report, runningEntryTime) in
                let workedTimeToday = report?.workedTimeOnDayOfRequest ?? 0
                return workedTimeToday + runningEntryTime
        }
    }()

    /// The amount of time left to meet the adjusted day baseline on the reference date.
    /// Returns `nil` if the reference date is not included in the period for which the target-reaching strategy is
    /// being calculated.
    public lazy var remainingTimeToDayBaseline: SignalProducer<TimeInterval?, NoError> = {
        return SignalProducer.combineLatest(strategyStartsToday.skipRepeats(),
                                            dayBaselineAdjustedToProgress.skipRepeats(),
                                            timeWorkedToday.skipRepeats())
            .map { (strategyStartsToday, dayBaselineAdjustedToProgress, timeWorkedToday) -> TimeInterval? in
                guard strategyStartsToday else {
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

    /// Calculates the amount of time worked from the beginning of the currently running time entry until the reference
    /// date. Emits zero values when there is no currently running time entry or it belongs to a project other than the
    /// one corresponding to the current time target.
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
