//
//  ReportPeriodsProducer.swift
//  TogglGoals
//
//  Created by David Dávila on 16.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

/// ReportPeriodsProducer contains logic to calculate one to two subperiods given a start and and an end date
/// represented by DayComponents...
class ReportPeriodsProducer {

    // MARK: - Exposed inputs

    var startDate: BindingTarget<DayComponents> { return _startDate.deoptionalizedBindingTarget }
    var endDate: BindingTarget<DayComponents> { return _endDate.deoptionalizedBindingTarget }
    var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }


    // MARK: - Backing properties

    private let _startDate = MutableProperty<DayComponents?>(nil)
    private let _endDate = MutableProperty<DayComponents?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _now = MutableProperty<Date?>(nil)


    // MARK: - Intermediate signals

    private lazy var todayProducer: SignalProducer<DayComponents, NoError>
        = SignalProducer.combineLatest(_calendar.producer.skipNil(), _now.producer.skipNil())
            .map { (calendar, now) in
                return calendar.dayComponents(from: now)
    }

    private lazy var yesterdayProducer: SignalProducer<DayComponents?, NoError>
        = SignalProducer.combineLatest(_calendar.producer.skipNil(),
                                       _now.producer.skipNil(),
                                       _startDate.producer.skipNil())
            .map { (calendar, now, startDate) in
                return try? calendar.previousDay(for: now, notBefore: startDate)
    }

    // MARK: - Exposed outputs

    lazy var fullPeriod: SignalProducer<Period, NoError> =
        SignalProducer.combineLatest(_startDate.producer.skipNil(),
                                     _endDate.producer.skipNil())
            .map { Period(start: $0, end: $1) }

    lazy var previousToTodayPeriod: SignalProducer<Period?, NoError> =
        SignalProducer.combineLatest(_startDate.producer.skipNil(), yesterdayProducer)
            .map { (start, yesterdayOrNil) in
                if let yesterday = yesterdayOrNil {
                    return Period(start: start, end: yesterday)
                } else {
                    return nil
                }
    }

    lazy var todayPeriod: SignalProducer<Period, NoError> =
        todayProducer.map { Period(start: $0, end: $0) }
}
