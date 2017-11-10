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

extension PeriodPreference: StorableInUserDefaults {
    private enum UserDefaultsKey: String {
        case typeMonthly = "MonthlyPeriodPreference"
        case typeWeekly = "WeeklyPeriodPreference"
        case startWeekday = "StartWeekDay"
    }
    func write(to defaults: UserDefaults) {
        switch self {
        case .monthly:
            defaults.set(true,  forKey: UserDefaultsKey.typeMonthly.rawValue)
            defaults.removeObject(forKey: UserDefaultsKey.typeWeekly.rawValue)
            defaults.removeObject(forKey: UserDefaultsKey.startWeekday.rawValue)
        case .weekly(let startDay):
            defaults.set(true,  forKey: UserDefaultsKey.typeWeekly.rawValue)
            defaults.removeObject(forKey: UserDefaultsKey.typeMonthly.rawValue)
            defaults.set(startDay.rawValue, forKey: UserDefaultsKey.startWeekday.rawValue)
        }
    }

    init?(userDefaults: UserDefaults) {
        if userDefaults.bool(forKey: UserDefaultsKey.typeMonthly.rawValue) {
            self = .monthly
        } else if userDefaults.bool(forKey: UserDefaultsKey.typeWeekly.rawValue),
            let startDay = Weekday(rawValue: userDefaults.integer(forKey: UserDefaultsKey.startWeekday.rawValue)) {
            self = .weekly(startDay: startDay)
        } else {
            return nil
        }
    }
}
