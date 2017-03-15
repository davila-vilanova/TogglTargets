//
//  DateTimeExtensions.swift
//  TogglGoals
//
//  Created by David Davila on 15.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

extension Calendar {
    func firstDayOfMonth(for date: Date) -> DateComponents {
        var first = dateComponents([.day, .month, .year], from: date)
        first.day = 1
        return first
    }

    func lastDayOfMonth(for date: Date) -> DateComponents {
        var last = dateComponents([.day, .month, .year], from: date)
        last.day = lastDayInMonth(for: date)
        return last
    }

    enum NextDayInMonthError: Error {
        case noMoreDaysInMonth
    }

    func nextDayInMonth(for date: Date) throws -> DateComponents {
        var comps = dateComponents([.day, .month, .year], from: date)
        let day = comps.day!
        guard day < lastDayInMonth(for: date) else {
            throw NextDayInMonthError.noMoreDaysInMonth
        }
        comps.day = day + 1
        return comps
    }

    private func lastDayInMonth(for date: Date) -> Int {
        let daysRange = range(of: .day, in: .month, for: date)!
        return daysRange.upperBound - 1
    }
}

extension DateComponents {
    static var dayComponents: Set<Calendar.Component> {
        return [.year, .month, .day]
    }

    var hasDayComponentsSet: Bool {
        return hasAllComponentsSet(from: DateComponents.dayComponents)
    }

    func hasAllComponentsSet(from requiredComponents: Set<Calendar.Component>) -> Bool {
        for calendarComponent in requiredComponents {
            if value(for: calendarComponent) == nil {
                return false
            }
        }
        return true
    }

    func trimmedToDayComponents() -> DateComponents {
        return trimmedToComponents(DateComponents.dayComponents)
    }

    func trimmedToComponents(_ components: Set<Calendar.Component>) -> DateComponents {
        var returnDateComponents = DateComponents()
        for calendarComponent in components {
            returnDateComponents.setValue(self.value(for: calendarComponent), for: calendarComponent)
        }
        return returnDateComponents
    }
}
