//
//  PeriodPreference.swift
//  TogglTargets
//
//  Created by David Dávila on 03.11.17.
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

/// Represents the user's preference for pursuing time targets in monthly or weekly periods.
enum PeriodPreference {
    /// Represents a user's preference for pursuing time targets in monthly periods.
    case monthly

    /// Represents a user's preference for pursuing time targets in weekly periods that start from a specified weekday.
    case weekly(startDay: Weekday)
}

extension PeriodPreference {

    /// Determines the `Period` that contains the specified point in time for this preference.
    ///
    /// - parameters:
    ///   - calendar: The calendar to use to interpret the specified point in time. This calendar's time zone will be 
    ///               used.
    ///   - date: The reference date which will be contained in the determined period.
    ///
    /// - returns: The period that conforms to this preference and contains the given point in time as interpreted
    ///              in the provided calendar.
    func period(in calendar: Calendar, for date: Date) -> Period {
        switch self {
        case .monthly:
            let first = calendar.firstDayOfMonth(for: date)
            let last = calendar.lastDayOfMonth(for: date)
            return Period(start: first, end: last)
        case .weekly(let startWeekday):
            let endWeekday = startWeekday.previous
            return Period(start: calendar.findClosestDay(matching: startWeekday,
                                                         startingFrom: date,
                                                         direction: .backward),
                          end: calendar.findClosestDay(matching: endWeekday,
                                                       startingFrom: date,
                                                       direction: .forward))
        }
    }
}

extension PeriodPreference: StorableInUserDefaults {

    /// The key strings user to store `PeriodPreference` values in the user defaults.
    private enum UserDefaultsKey: String {
        case typeMonthly = "MonthlyPeriodPreference"
        case typeWeekly = "WeeklyPeriodPreference"
        case startWeekday = "StartWeekDay"
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

    func write(to defaults: UserDefaults) {
        switch self {
        case .monthly:
            defaults.set(true, forKey: UserDefaultsKey.typeMonthly.rawValue)
            defaults.removeObject(forKey: UserDefaultsKey.typeWeekly.rawValue)
            defaults.removeObject(forKey: UserDefaultsKey.startWeekday.rawValue)
        case .weekly(let startDay):
            defaults.set(true, forKey: UserDefaultsKey.typeWeekly.rawValue)
            defaults.removeObject(forKey: UserDefaultsKey.typeMonthly.rawValue)
            defaults.set(startDay.rawValue, forKey: UserDefaultsKey.startWeekday.rawValue)
        }
    }

    static func delete(from userDefaults: UserDefaults) {
        for key in [UserDefaultsKey.typeMonthly, .typeWeekly, .startWeekday] {
            userDefaults.removeObject(forKey: key.rawValue)
        }
    }
}

extension PeriodPreference {
    /// Whether this represents a preference for a monthly period.
    var isMonthly: Bool {
        switch self {
        case .monthly: return true
        default: return false
        }
    }

    /// Whether this represents a preference for a weekly period.
    var isWeekly: Bool {
        switch self {
        case .weekly: return true
        default: return false
        }
    }

    /// If this is a weekly period preference, the preferred weekday to start the week. `nil` otherwise.
    var selectedWeekday: Weekday? {
        switch self {
        case .weekly(let weekday): return weekday
        default: return nil
        }
    }
}

/// Determines whether the specified period preference is montly.
func isMonthly(_ pref: PeriodPreference) -> Bool {
    return pref.isMonthly
}

/// Determines whether the specified period preference is weekly.
func isWeekly(_ pref: PeriodPreference) -> Bool {
    return pref.isWeekly
}

/// Determines the preferred weekday to start the week if the specified period preference is a weekly period preference.
/// Returns `nil` if the specified preference is not weekly.
func selectedWeekday(_ pref: PeriodPreference) -> Weekday? {
    return pref.selectedWeekday
}
