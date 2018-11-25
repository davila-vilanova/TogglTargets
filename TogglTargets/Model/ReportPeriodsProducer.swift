//
//  ReportPeriodsProducer.swift
//  TogglTargets
//
//  Created by David Dávila on 16.11.17.
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
import Result
import ReactiveSwift

/// Represents a time period for which a two part time report is scoped, itself divided in two parts:
/// 1. the `Period` from the start of the overall period until the day before the corresponding time report report is
///    requested,
/// 2. the `Period` corresponding to the day on which the time reports are requested.
struct TwoPartTimeReportPeriod {

    /// The full `Period` for which two part time report is scoped.
    let scope: Period

    /// The `Period` corresponding to the beginning of `full` until the day before the day on which the report is
    /// requested.
    ///
    /// It should be `nil` if the report is requested on the first day of `full` and non-`nil` in any other case.
    let previousToDayOfRequest: Period?

    /// The `DayComponents` corresponding to the day in which the time period will be requested.
    /// The day of request is expected to be inside the range defined by `full.start` start and `full.end`.
    /// It is used to generate the second part (`forDayOfRequest`) of the period represented by this instance.
    private let dayOfRequest: DayComponents

    /// The `Period` corresponding to the day in which the time report is requested.
    /// Both `start` and `end` properties will correspond to the same day.
    /// The day can be any value between `full.start` and `full.end`.
    var forDayOfRequest: Period { return Period(start: dayOfRequest, end: dayOfRequest) }

    /// Initializes a new value.
    init(scope: Period, previousToDayOfRequest: Period?, dayOfRequest: DayComponents) {
        self.scope = scope
        self.previousToDayOfRequest = previousToDayOfRequest
        self.dayOfRequest = dayOfRequest
    }
}

extension TwoPartTimeReportPeriod: Equatable {
    static func == (lhs: TwoPartTimeReportPeriod, rhs: TwoPartTimeReportPeriod) -> Bool {
        return lhs.scope == rhs.scope
            && lhs.previousToDayOfRequest == rhs.previousToDayOfRequest
            && lhs.dayOfRequest == rhs.dayOfRequest
    }
}

/// Produces `TwoPartTimeReportPeriod` values based on the incoming `PeriodPreference`, `currentDate` and `calendar`
/// values.
class ReportPeriodsProducer {

    // MARK: - Exposed inputs

    /// Binding target for `PeriodPreference` representing the user preference corresponding to how to determine the
    /// current period for scoping the requested time reports. E.g., monthly, or weekly starting on Monday.
    var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }

    /// Binding target for the current `Calendar` used to perform calendrical computations.
    var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }

    /// Binding target for the application-wide `currentDate` values.
    var currentDate: BindingTarget<Date> { return _currentDate.deoptionalizedBindingTarget }

    // MARK: - Backing properties

    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _currentDate = MutableProperty<Date?>(nil)

    // MARK: - Intermediate signals

    /// Produces `Period` values representing the full scope of the current period.
    private lazy var fullPeriod: SignalProducer<Period, NoError> =
        SignalProducer.combineLatest(_periodPreference.producer.skipNil(),
                                     _calendar.producer.skipNil(),
                                     _currentDate.producer.skipNil())
            .map { $0.period(in: $1, for: $2) }

    /// Produces `DayComponents` values representing the day corresponding to `currentDate`
    private lazy var today: SignalProducer<DayComponents, NoError>
        = SignalProducer.combineLatest(_calendar.producer.skipNil(), _currentDate.producer.skipNil())
            .map { (calendar, currentDate) in
                return calendar.dayComponents(from: currentDate)
    }

    /// Produces `DayComponents` values representing the day previous to the day corresponding to `currentDate`, as long
    /// as that day is not earlier than the start of the current full period value, and produces `nil` otherwise.
    private lazy var periodUntilYesterday: SignalProducer<Period?, NoError>
        = SignalProducer.combineLatest(_calendar.producer.skipNil(),
                                       _currentDate.producer.skipNil(),
                                       fullPeriod)
            .map { (calendar, currentDate, fullPeriod) in
                let today = calendar.dayComponents(from: currentDate)
                guard let yesterday = calendar.previousDay(before: today, notEarlierThan: fullPeriod.start) else {
                    return nil
                }
                return Period(start: fullPeriod.start, end: yesterday)
    }

    // MARK: - Exposed output

    /// Emits the produced `TwoPartTimeReportPeriod` values.
    lazy var twoPartPeriod: SignalProducer<TwoPartTimeReportPeriod, NoError> =
        SignalProducer.combineLatest(fullPeriod, periodUntilYesterday, today)
            .map { TwoPartTimeReportPeriod(scope: $0, previousToDayOfRequest: $1, dayOfRequest: $2)
    }
}
