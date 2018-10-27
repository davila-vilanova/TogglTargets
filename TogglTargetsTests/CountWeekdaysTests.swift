//
//  CountWeekdaysTests.swift
//  TogglTargets
//
//  Created by David Davila on 06.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

class CountWeekdaysTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testCountWeekdaysWorksInAllKnownTimezonesForMarch() {
        let startComps = DayComponents(year: 2017, month: 3, day: 1)//, hour: 0, minute: 0)
        let endComps = DayComponents(year: 2017, month: 3, day: 31)//, hour: 23, minute: 59)

        let expectedCount: Dictionary<Weekday, Int> =
            [ .monday : 4,
              .tuesday : 4,
              .wednesday : 5,
              .thursday : 5,
              .friday : 5,
              .saturday : 4,
              .sunday : 4 ]

        var calendar = Calendar(identifier: .iso8601)

        var iterations = 0

        for timezoneId in TimeZone.knownTimeZoneIdentifiers {
            let tz = TimeZone(identifier: timezoneId)!

            calendar.timeZone = tz

            for day in Weekday.allDaysOrdered {
                let count = try! calendar.countWeekdaysMatching(day, from: startComps, until: endComps)
                let expected = expectedCount[day]!
                XCTAssertEqual(count, expected, "(count (\(count)) does not match expected (\(expected)) for day: \(day) in timezone: \(tz.identifier) secondsFromGMT=\(tz.secondsFromGMT()))")
                iterations += 1
            }
        }

        print("iterations=\(iterations)")
    }

    func testCountWeekdaysWorksInAllKnownTimezonesForOctober() {
        let startComps = DayComponents(year: 2016, month: 10, day: 1)
        let endComps = DayComponents(year: 2016, month: 10, day: 31)

        let expectedCount: Dictionary<Weekday, Int> =
            [ .monday : 5,
              .tuesday : 4,
              .wednesday : 4,
              .thursday : 4,
              .friday : 4,
              .saturday : 5,
              .sunday : 5 ]

        var calendar = Calendar(identifier: .iso8601)

        var iterations = 0

        for timezoneId in TimeZone.knownTimeZoneIdentifiers {
            let tz = TimeZone(identifier: timezoneId)!

            calendar.timeZone = tz

            for day in Weekday.allDaysOrdered {
                let count = try! calendar.countWeekdaysMatching(day, from: startComps, until: endComps)
                let expected = expectedCount[day]!
                XCTAssertEqual(count, expected, "(count (\(count)) does not match expected (\(expected)) for day: \(day) in timezone: \(tz.identifier) secondsFromGMT=\(tz.secondsFromGMT()))")
                iterations += 1
            }
        }
        
        print("iterations=\(iterations)")
    }

    func testPerformanceExample() {
        let tz = TimeZone(identifier: "Europe/London")!

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = tz
        let day = Weekday.monday
        let startComps = DayComponents(year: 2015, month: 10, day: 1)
        let endComps = DayComponents(year: 2015, month: 10, day: 31)

        self.measure {
            _ = try! calendar.countWeekdaysMatching(day, from: startComps, until: endComps)
        }
    }
}
