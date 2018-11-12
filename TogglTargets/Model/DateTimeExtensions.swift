//
//  DateTimeExtensions.swift
//  TogglTargets
//
//  Created by David Davila on 15.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

/// A date identified by year, month and day of the month.
/// As opposed to `DateComponents`, these three components are non optional, and no other components are present.
struct DayComponents: Equatable {
    var year: Int
    var month: Int
    var day: Int

    /// Returns the date represented by this instance as a `DateComponents` instance.
    func toDateComponents() -> DateComponents {
        return DateComponents(year: year, month: month, day: day)
    }

    static func == (lhs: DayComponents, rhs: DayComponents) -> Bool {
        return lhs.day == rhs.day &&
            lhs.month == rhs.month &&
            lhs.year == rhs.year
    }
}

extension DayComponents {
    /// Returns the date represented by this instance as a String formatted as a ISO8601 date.
    var iso8601String: String {
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

extension Calendar {
    /// Extracts the day components from a provided absolute point in time.
    ///
    /// - parameters:
    ///   - date: The `Date` instance from which to extract the day components.
    ///
    ///   - returns: A `DayComponents` instance representing the year, month and day that contains the provided `Date`
    ///              in the calendar's time zone.
    func dayComponents(from date: Date) -> DayComponents {
        let dateComps = dateComponents([.year, .month, .day], from: date)
        return DayComponents(year: dateComps.year!, month: dateComps.month!, day: dateComps.day!)
    }

    /// Returns a date created with the provided day components
    ///
    /// - parameters:
    ///   - dayComponents: Used as input to the search algorithm for finding the corresponding date.
    ///
    ///   - returns: A new `Date`, or `nil` if the components are invalid.
    func date(from dayComponents: DayComponents) -> Date? {
        let dateComponents = dayComponents.toDateComponents()
        guard let date = date(from: dateComponents) else {
            return nil
        }
        return date
    }
}

extension Calendar {

    /// Returns the first day of the month for a given date.
    ///
    /// - parameters:
    ///   - date: An absolute point in time.
    ///
    ///   - returns: The components of the first day of the month that contains the provided `Date`, interprete in the
    ///              calendar's time zone.
    func firstDayOfMonth(for date: Date) -> DayComponents {
        var dayComps = dayComponents(from: date)
        dayComps.day = 1
        return dayComps
    }

    /// Returns the last day of the month for a given date.
    ///
    /// - parameters:
    ///   - date: An absolute point in time.
    ///
    ///   - returns: The components of the last day of the month that contains the provided `Date`, interprete in the
    ///              calendar's time zone.
    func lastDayOfMonth(for date: Date) -> DayComponents {
        var dayComps = dayComponents(from: date)
        dayComps.day = lastDayInMonth(for: date)
        return dayComps
    }

    /// Returns the day that follows the day represented by the specified components.
    ///
    /// - parameters:
    ///   - originalDay: The day used as a reference to calculate the following day.
    ///   - upperLimitDay: The latest possible day that should be returned.
    ///
    ///   - returns: The components of the day that follows the specified day, or `nil` if the computed day would be a
    ///              later day than the one represented by upperLimitDay
    func nextDay(after originalDay: DayComponents, notLaterThan upperLimitDay: DayComponents) -> DayComponents? {
        let oneDayIncrement = DateComponents(day: 1)
        guard let originalDate = date(from: originalDay),
            let adjustedDate = date(byAdding: oneDayIncrement, to: originalDate),
            let upperLimitDate = date(from: upperLimitDay),
            !isDate(adjustedDate, inLaterDayThan: upperLimitDate) else {
                return nil
        }
        return dayComponents(from: adjustedDate)
    }

    /// Returns the day that precedes the day represented by the specified components.
    ///
    /// - parameters:
    ///   - originalDay: The day used as a reference to calculate the preceding day.
    ///   - lowerLimitDay: The earliest possible day that should be returned.
    ///
    ///   - returns: The components of the day that precedes the specified day, or `nil` if the computed day would be an
    ///              earlier day than the one represented by lowerLimitDay
    func previousDay(before originalDay: DayComponents, notEarlierThan lowerLimitDay: DayComponents) -> DayComponents? {
        let oneDayDecrement = DateComponents(day: -1)
        guard let originalDate = date(from: originalDay),
            let adjustedDate = date(byAdding: oneDayDecrement, to: originalDate),
            let lowerLimitDate = date(from: lowerLimitDay),
            !isDate(adjustedDate, inEarlierDayThan: lowerLimitDate) else {
                return nil
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
