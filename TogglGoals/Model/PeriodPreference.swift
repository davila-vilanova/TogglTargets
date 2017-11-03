//
//  PeriodPreference.swift
//  TogglGoals
//
//  Created by David Dávila on 03.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

enum PeriodPreference {
    case monthly
    case weekly(startDay: Weekday)
}

extension PeriodPreference {
    func currentPeriod(for calendar: Calendar, now: Date) -> Period {
        switch self {
        case .monthly:
            let first = calendar.firstDayOfMonth(for: now)
            let last = calendar.lastDayOfMonth(for: now)
            return Period(start: first, end: last)
        case .weekly(let startWeekday):
            let endWeekday = startWeekday.previous
            return Period(start: calendar.findClosestDay(matching: startWeekday, startingFrom: now, direction: .backward),
                          end: calendar.findClosestDay(matching: endWeekday, startingFrom: now, direction: .forward))
        }
    }
}
