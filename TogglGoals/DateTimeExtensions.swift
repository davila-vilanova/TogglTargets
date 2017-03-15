//
//  DateTimeExtensions.swift
//  TogglGoals
//
//  Created by David Davila on 15.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

extension Calendar {
    func dayComponents(from date: Date) -> DateComponents {
        return dateComponents(DateComponents.dayComponents, from: date)
    }

    func firstDayOfMonth(for date: Date) -> DateComponents {
        var comps = dayComponents(from: date)
        comps.day = 1
        return comps
    }

    func lastDayOfMonth(for date: Date) -> DateComponents {
        var comps = dayComponents(from: date)
        comps.day = lastDayInMonth(for: date)
        return comps
    }

    enum NextDayInMonthError: Error {
        case noMoreDaysInMonth
    }

    func nextDayInMonth(for date: Date) throws -> DateComponents {
        var comps = dayComponents(from: date)
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
