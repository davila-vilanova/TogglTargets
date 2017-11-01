//
//  DateTimeExtensionsTests.swift
//  TogglGoals
//
//  Created by David Davila on 19.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

class DateTimeExtensionsTests: XCTestCase {

    func testCalculateNextDayInAllKnownTimezones() {
        var calendar = Calendar(identifier: .iso8601)

        func testCase(original: DayComponents, expected: DayComponents) {
            let upperLimitComponents = DayComponents(year: 2020, month: 3, day: 31)

            let date = try! calendar.date(from: original)
            let calculated = try! calendar.nextDay(for: date, notAfter: upperLimitComponents)
            XCTAssertEqual(calculated, expected)
        }

        for timezoneId in TimeZone.knownTimeZoneIdentifiers {
            let tz = TimeZone(identifier: timezoneId)!
            calendar.timeZone = tz

            testCase(original: DayComponents(year: 2016, month: 2, day: 26),
                     expected: DayComponents(year: 2016, month: 2, day: 27))

            testCase(original: DayComponents(year: 2016, month: 2, day: 28),
                     expected: DayComponents(year: 2016, month: 2, day: 29))
            testCase(original: DayComponents(year: 2017, month: 2, day: 28),
                     expected: DayComponents(year: 2017, month: 3, day: 1))

            testCase(original: DayComponents(year: 2017, month: 12, day: 31),
                     expected: DayComponents(year: 2018, month: 1, day: 1))
        }

        // Daylights saving time (CET)
        testCase(original: DayComponents(year: 2016, month: 3, day: 26),
                 expected: DayComponents(year: 2016, month: 3, day: 27))
        testCase(original: DayComponents(year: 2016, month: 10, day: 29),
                 expected: DayComponents(year: 2016, month: 10, day: 30))
    }


    func testCalculatePreviousDayInAllKnownTimezones() {
        var calendar = Calendar(identifier: .iso8601)

        func testCase(original: DayComponents, expected: DayComponents) {
            let lowerLimitComponents = DayComponents(year: 2015, month: 3, day: 31)

            let date = try! calendar.date(from: original)
            let calculated = try! calendar.previousDay(for: date, notBefore: lowerLimitComponents)
            XCTAssertEqual(calculated, expected)
        }

        for timezoneId in TimeZone.knownTimeZoneIdentifiers {
            let tz = TimeZone(identifier: timezoneId)!
            calendar.timeZone = tz

            testCase(original: DayComponents(year: 2016, month: 2, day: 27),
                     expected: DayComponents(year: 2016, month: 2, day: 26))

            testCase(original: DayComponents(year: 2016, month: 2, day: 29),
                     expected: DayComponents(year: 2016, month: 2, day: 28))
            testCase(original: DayComponents(year: 2017, month: 3, day: 1),
                     expected: DayComponents(year: 2017, month: 2, day: 28))

            testCase(original: DayComponents(year: 2018, month: 1, day: 1),
                     expected: DayComponents(year: 2017, month: 12, day: 31))

        }

        // Daylights saving time (CET)
        testCase(original: DayComponents(year: 2016, month: 3, day: 27),
                 expected: DayComponents(year: 2016, month: 3, day: 26))
        testCase(original: DayComponents(year: 2016, month: 10, day: 30),
                 expected: DayComponents(year: 2016, month: 10, day: 29))
    }
}
