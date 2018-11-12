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
    /// - returns: A `DayComponents` instance representing the year, month and day that contains the provided `Date`
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
    /// - returns: A new `Date`, or `nil` if the components are invalid.
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
    /// - returns: The components of the first day of the month that contains the provided `Date`, interprete in the
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
    /// - returns: The components of the last day of the month that contains the provided `Date`, interprete in the
    ///              calendar's time zone.
    func lastDayOfMonth(for date: Date) -> DayComponents {
        var dayComps = dayComponents(from: date)
        dayComps.day = countOfDaysInMonth(for: date) - 1
        return dayComps
    }

    /// Returns the day that follows the day represented by the specified components.
    ///
    /// - parameters:
    ///   - originalDay: The day used as a reference to calculate the following day.
    ///   - upperLimitDay: The latest possible day that should be returned.
    ///
    /// - returns: The components of the day that follows the specified day, or `nil` if the computed day would be a
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
    /// - returns: The components of the day that precedes the specified day, or `nil` if the computed day would be an
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

    /// Returns the amount of days in the month that contains a given `Date`.
    /// 
    /// - parameters:
    ///   - date: An absolute point in time.
    ///
    /// - returns: The amount of days in the month that contains the specified point in time as interpreted in the
    ///              calendar's time zone.
    func countOfDaysInMonth(for date: Date) -> Int {
        let daysRange = range(of: .day, in: .month, for: date)!
        return daysRange.upperBound
    }
}

extension Calendar {
    /// Returns whether a specified date is contained in an earlier day than a reference date.
    /// Both dates are interpreted according to the calendar's time zone.
    ///
    /// - parameters:
    ///   - compared: The date to evaluate. 
    ///   - reference: A reference date.
    ///
    /// - returns: `true` if the day that contains `compared` in the calendar's time zone is an earlier day than
    ///              the day that contains `reference`, false otherwise.
    func isDate(_ compared: Date, inEarlierDayThan reference: Date) -> Bool {
        return compared < reference && !isDate(compared, inSameDayAs: reference)
    }

    /// Returns whether a specified date is contained in a later day than a reference date.
    /// Both dates are interpreted according to the calendar's time zone.
    ///
    /// - parameters:
    ///   - compared: The date to evaluate. 
    ///   - reference: A reference date.
    ///
    /// - returns: `true` if the day that contains `compared` in the calendar's time zone is a later day than
    ///              the day that contains `reference`, false otherwise.
    func isDate(_ compared: Date, inLaterDayThan reference: Date) -> Bool {
        return compared > reference && !isDate(compared, inSameDayAs: reference)
    }
}

extension Calendar {
    /// Find the closest day to a specified point in time that matches the sought weekday using the provided search
    /// direction.
    ///
    /// - parameters:
    ///   - weekday: The weekday to find.
    ///   - startingFrom: The point in time from which to begin the search. This is an absolute point in time that will
    ///                   be interpreted as a day in the calendar's time zone.
    ///
    /// - returns: The components of the day which matches the desired weekday and that's been found to be the closest
    ///              to the reference point in time.
    func findClosestDay(matching weekday: Weekday,
                        startingFrom startDate: Date,
                        direction: SearchDirection) -> DayComponents {
        let weekdayCount = veryShortWeekdaySymbols.count
        let startDayDate = startOfDay(for: startDate)

        let range: CountableClosedRange<Int> = {
            let limit = weekdayCount - 1
            switch direction {
            case .forward: return 0...limit
            case .backward: return (0 - limit)...0
            }
        }()

        let foundDate: Date? = {
            for dayAmount in range {
                if let candidate = date(byAdding: .day,
                                        value: dayAmount,
                                        to: startDayDate,
                                        wrappingComponents: false),
                    dateComponents([.weekday], from: candidate).weekday == weekday.indexInGregorianCalendar {
                    return candidate
                }
            }
            assert(false)
            return nil
        }()

        let unwrappedDate = foundDate! // Assumed it cannot fail for range-bound weekday
        return dayComponents(from: unwrappedDate)
    }
}

extension Calendar {
    /// Returns a calendar compatible with Toggl's service.
    static var iso8601: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }
}
