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

struct TwoPartTimeReportPeriods {
    let full: Period
    let previousToToday: Period?
    let today: Period?
} // TODO

/// ReportPeriodsProducer contains logic to calculate one to two subperiods given a start and and an end date
/// represented by DayComponents...
class ReportPeriodsProducer {

    // MARK: - Exposed inputs

    var reportPeriod: BindingTarget<Period> { return _reportPeriod.deoptionalizedBindingTarget }
    var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }


    // MARK: - Backing properties

    private let _reportPeriod = MutableProperty<Period?>(nil)
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
                                       _reportPeriod.producer.skipNil())
            .map { (calendar, now, reportPeriod) in
                return try? calendar.previousDay(for: now, notBefore: reportPeriod.start)
    }

    // MARK: - Exposed output

    lazy var twoPartPeriod: SignalProducer<TwoPartTimeReportPeriods, NoError> =
        SignalProducer.combineLatest(_reportPeriod.producer.skipNil(), yesterdayProducer, todayProducer)
            .map { (fullPeriod, yesterdayOrNil, today) in
                let previousToToday: Period? = {
                    if let yesterday = yesterdayOrNil {
                        return Period(start: fullPeriod.start, end: yesterday)
                    } else {
                        return nil
                    }
                }()
                let todayPeriod = Period(start: today, end: today)
                return TwoPartTimeReportPeriods(full: fullPeriod, previousToToday: previousToToday, today: todayPeriod)
    }
}
