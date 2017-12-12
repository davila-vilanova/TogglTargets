//
//  DateTimeExtensions.swift
//  TogglGoals
//
//  Created by David Davila on 15.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct DayComponents: Equatable {
    var year: Int
    var month: Int
    var day: Int

    enum InvalidComponentsError: Error {
        case invalidComponents // TODO: naming
    }

    func toDateComponents() -> DateComponents {
        return DateComponents(year: year, month: month, day: day)
    }

    static func ==(lhs: DayComponents, rhs: DayComponents) -> Bool {
        return lhs.day == rhs.day &&
            lhs.month == rhs.month &&
            lhs.year == rhs.year
    }
}

extension DayComponents {
    var iso8601String: String {
        return String(format:"%04d-%02d-%02d", year, month, day)
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

    enum DayCalculationError: Error {
        case resultExceedsProvidedBoundary
    }

    // TODO: apples to apples
    func nextDay(for originalDate: Date, notAfter: DayComponents) throws -> DayComponents {
        // TODO: could use date(bySetting component: Calendar.Component, value: Int, of date: Date) -> Date?
        let oneDayIncrement = DateComponents(day: 1)
        let adjustedDate = date(byAdding: oneDayIncrement, to: originalDate)!
        let notAfterDate = try date(from: notAfter)
        if isDate(adjustedDate, inLaterDayThan: notAfterDate) {
            throw DayCalculationError.resultExceedsProvidedBoundary
        }
        return dayComponents(from: adjustedDate)
    }

    func previousDay(for originalDate: Date, notBefore: DayComponents) throws -> DayComponents {
        let oneDayDecrement = DateComponents(day: -1)
        let adjustedDate = date(byAdding: oneDayDecrement, to: originalDate)!
        let notBeforeDate = try date(from: notBefore)
        if isDate(adjustedDate, inEarlierDayThan: notBeforeDate) {
            throw DayCalculationError.resultExceedsProvidedBoundary
        }
        return dayComponents(from: adjustedDate)
    }

    func countOfDaysInMonth(for date: Date) -> Int {
        let daysRange = range(of: .day, in: .month, for: date)!
        return daysRange.upperBound
    }
    
    private func lastDayInMonth(for date: Date) -> Int {
        return countOfDaysInMonth(for: date)  - 1
    }
}

extension Calendar {
    func isDate(_ compared: Date, inEarlierDayThan reference: Date) -> Bool {
        return compared < reference && !isDate(compared, inSameDayAs: reference)
    }

    func isDate(_ compared: Date, inLaterDayThan reference: Date) -> Bool {
        return compared > reference && !isDate(compared, inSameDayAs: reference)
    }
}

extension Calendar {
    func findClosestWeekdayDate(startingFrom: Date,
                                matchingWeekDay soughtWeekday: Int,
                                direction: SearchDirection) -> Date? {
        let weekdayCount = veryShortWeekdaySymbols.count
        let startDayDate = startOfDay(for: startingFrom)

        let range: CountableClosedRange<Int> = {
            let limit = weekdayCount - 1
            switch direction {
            case .forward: return 0...limit
            case .backward: return (0 - limit)...0
            }
        }()

        for dayAmount in range {
            if let candidate = date(byAdding: .day,
                                    value: dayAmount,
                                    to: startDayDate,
                                    wrappingComponents: false),
                dateComponents([.weekday], from: candidate).weekday == soughtWeekday {
                return candidate
            }
        }
        return nil
    }

    func findClosestDay(matching weekday: Weekday,
                        startingFrom date: Date,
                        direction: SearchDirection) -> DayComponents {
        let date =
            findClosestWeekdayDate(startingFrom: date,
                                   matchingWeekDay: weekday.indexInGregorianCalendar,
                                   direction: direction)! // Assumed it cannot fail for range-bound weekday
        return dayComponents(from: date)
    }
}

extension Calendar {
    static var iso8601: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }
}
