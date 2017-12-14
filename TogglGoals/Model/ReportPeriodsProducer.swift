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

struct TwoPartTimeReportPeriod {
    let full: Period
    let previousToToday: Period?
    let today: Period?
}

/// ReportPeriodsProducer contains logic to calculate one to two subperiods given a start and and an end date
/// represented by DayComponents...
class ReportPeriodsProducer {

    // MARK: - Exposed inputs

    var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }
    var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    var currentDate: BindingTarget<Date> { return _currentDate.deoptionalizedBindingTarget }


    // MARK: - Backing properties

    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _currentDate = MutableProperty<Date?>(nil)


    // MARK: - Intermediate signals

    private lazy var fullPeriodProducer: SignalProducer<Period, NoError> =
        SignalProducer.combineLatest(_periodPreference.producer.skipNil(),
                                     _calendar.producer.skipNil(),
                                     _currentDate.producer.skipNil())
            .map { $0.currentPeriod(in: $1, for: $2) }

    private lazy var todayProducer: SignalProducer<DayComponents, NoError>
        = SignalProducer.combineLatest(_calendar.producer.skipNil(), _currentDate.producer.skipNil())
            .map { (calendar, currentDate) in
                return calendar.dayComponents(from: currentDate)
    }

    private lazy var yesterdayProducer: SignalProducer<DayComponents?, NoError>
        = SignalProducer.combineLatest(_calendar.producer.skipNil(),
                                       _currentDate.producer.skipNil(),
                                       fullPeriodProducer)
            .map { (calendar, currentDate, reportPeriod) in
                return try? calendar.previousDay(for: currentDate, notBefore: reportPeriod.start)
    }

    // MARK: - Exposed output

    lazy var twoPartPeriod: SignalProducer<TwoPartTimeReportPeriod, NoError> =
        SignalProducer.combineLatest(fullPeriodProducer, yesterdayProducer, todayProducer)
            .map { (fullPeriod, yesterdayOrNil, today) in
                let previousToToday: Period? = {
                    if let yesterday = yesterdayOrNil {
                        return Period(start: fullPeriod.start, end: yesterday)
                    } else {
                        return nil
                    }
                }()
                let todayPeriod = Period(start: today, end: today)
                return TwoPartTimeReportPeriod(full: fullPeriod, previousToToday: previousToToday, today: todayPeriod)
    }
}
