//
//  DateTimeExtensionsTests.swift
//  TogglTargets
//
//  Created by David Davila on 19.03.17.
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

import XCTest

class DateTimeExtensionsTests: XCTestCase {

    func testCalculateNextDayInAllKnownTimezones() {
        var calendar = Calendar(identifier: .iso8601)

        func testCase(original: DayComponents, expected: DayComponents) {
            let upperLimitComponents = DayComponents(year: 2020, month: 3, day: 31)

            let calculated = calendar.nextDay(after: original, notLaterThan: upperLimitComponents)
            XCTAssertEqual(calculated, expected)
        }

        for timezoneId in TimeZone.knownTimeZoneIdentifiers {
            let tz = TimeZone(identifier: timezoneId)! // swiftlint:disable:this identifier_name
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

            let calculated = calendar.previousDay(before: original, notEarlierThan: lowerLimitComponents)
            XCTAssertEqual(calculated, expected)
        }

        for timezoneId in TimeZone.knownTimeZoneIdentifiers {
            let tz = TimeZone(identifier: timezoneId)! // swiftlint:disable:this identifier_name
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
