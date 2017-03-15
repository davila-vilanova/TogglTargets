//
//  DateTimeExtensions.swift
//  TogglGoals
//
//  Created by David Davila on 15.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct DayComponents {
    var year: Int
    var month: Int
    var day: Int

    enum InvalidComponentsError: Error {
        case invalidComponents // TODO: naming
    }

    func toDateComponents() -> DateComponents {
        return DateComponents(year: year, month: month, day: day)
    }
}

extension Calendar {
    func dayComponents(from date: Date) -> DayComponents {
        let dateComps = dateComponents([.year, .month, .day], from: date)
        return DayComponents(year: dateComps.year!, month: dateComps.month!, day: dateComps.day!)
    }

    func date(from dayComponents: DayComponents) throws -> Date {
        let dateComponents = dayComponents.toDateComponents()
        guard let date = date(from: dateComponents) else {
            throw DayComponents.InvalidComponentsError.invalidComponents
        }
        return date
    }
}

extension Calendar {
    func firstDayOfMonth(for date: Date) -> DayComponents {
        var dayComps = dayComponents(from: date)
        dayComps.day = 1
        return dayComps
    }

    func lastDayOfMonth(for date: Date) -> DayComponents {
        var dayComps = dayComponents(from: date)
        dayComps.day = lastDayInMonth(for: date)
        return dayComps
    }

    enum NextDayInMonthError: Error {
        case noMoreDaysInMonth
    }

    func nextDayInMonth(for date: Date) throws -> DayComponents {
        var dayComps = dayComponents(from: date)
        guard dayComps.day < lastDayInMonth(for: date) else {
            throw NextDayInMonthError.noMoreDaysInMonth
        }
        dayComps.day += 1
        return dayComps
    }

    private func lastDayInMonth(for date: Date) -> Int {
        let daysRange = range(of: .day, in: .month, for: date)!
        return daysRange.upperBound - 1
    }
}
