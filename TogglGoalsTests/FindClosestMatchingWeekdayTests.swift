//
//  FindClosestMatchingWeekdayTests.swift
//  TogglGoalsTests
//
//  Created by David Dávila on 01.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

class FindClosestMatchingWeekdayTests : XCTestCase {

    func testBaseCaseForwards() {
        let reference = DayComponents(year: 2017, month: 11, day: 10) // Friday
        testForEachWeekdayAndTimezone(direction: .forward,
                                      referenceDay: reference,
                                      expectedDict: [.sunday:       reference.changing(day: 12),
                                                     .monday:       reference.changing(day: 13),
                                                     .tuesday:      reference.changing(day: 14),
                                                     .wednesday:    reference.changing(day: 15),
                                                     .thursday:     reference.changing(day: 16),
                                                     .friday:       reference,
                                                     .saturday:     reference.changing(day: 11)])
    }

    func testBaseCaseBackwards() {
        let reference = DayComponents(year: 2017, month: 11, day: 10) // Friday
        testForEachWeekdayAndTimezone(direction: .backward,
                                      referenceDay: reference,
                                      expectedDict:  [.sunday:       reference.changing(day: 5),
                                                      .monday:       reference.changing(day: 6),
                                                      .tuesday:      reference.changing(day: 7),
                                                      .wednesday:    reference.changing(day: 8),
                                                      .thursday:     reference.changing(day: 9),
                                                      .friday:       reference,
                                                      .saturday:     reference.changing(day: 4)])
    }

    func testHigherComponentsShiftForwards() {
        let reference = DayComponents(year: 2017, month: 12, day: 29) // Friday
        testForEachWeekdayAndTimezone(direction: .forward,
                                      referenceDay: reference,
                                      expectedDict: [.sunday :      reference.changing(day: 31),
                                                     .monday:       DayComponents(year: 2018, month: 1, day: 1),
                                                     .tuesday:      DayComponents(year: 2018, month: 1, day: 2),
                                                     .wednesday:    DayComponents(year: 2018, month: 1, day: 3),
                                                     .thursday:     DayComponents(year: 2018, month: 1, day: 4),
                                                     .friday:       reference,
                                                     .saturday:     reference.changing(day: 30)])
    }

    func testHigherComponentsShiftBackwards() {
        let reference = DayComponents(year: 2018, month: 1, day: 3) // Wednesday
        testForEachWeekdayAndTimezone(direction: .backward,
                                      referenceDay: reference,
                                      expectedDict: [.sunday :      DayComponents(year: 2017, month: 12, day: 31),
                                                     .monday:       reference.changing(day: 1),
                                                     .tuesday:      reference.changing(day: 2),
                                                     .wednesday:    reference,
                                                     .thursday:     DayComponents(year: 2017, month: 12, day: 28),
                                                     .friday:       DayComponents(year: 2017, month: 12, day: 29),
                                                     .saturday:     DayComponents(year: 2017, month: 12, day: 30)])
    }

    func testOverDSTSwitchOffForwards() {
        let reference = DayComponents(year: 2017, month: 10, day: 26) // Thursday
        testForEachWeekdayAndTimezone(direction: .forward,
                                      referenceDay: reference,
                                      expectedDict: [.sunday :      reference.changing(day: 29),
                                                     .monday:       reference.changing(day: 30),
                                                     .tuesday:      reference.changing(day: 31),
                                                     .wednesday:    reference.changing(month: 11, day: 1),
                                                     .thursday:     reference,
                                                     .friday:       reference.changing(day: 27),
                                                     .saturday:     reference.changing(day: 28)])
    }

    func testOverDSTSwitchOffBackwards() {
        let reference = DayComponents(year: 2017, month: 10, day: 31) // Tuesday
        testForEachWeekdayAndTimezone(direction: .backward,
                                      referenceDay: reference,
                                      expectedDict: [.sunday :      reference.changing(day: 29),
                                                     .monday:       reference.changing(day: 30),
                                                     .tuesday:      reference,
                                                     .wednesday:    reference.changing(day: 25),
                                                     .thursday:     reference.changing(day: 26),
                                                     .friday:       reference.changing(day: 27),
                                                     .saturday:     reference.changing(day: 28)])
    }

    func testOverDSTSwitchOnForwards() {
        let reference = DayComponents(year: 2018, month: 3, day: 22) // Thursday
        testForEachWeekdayAndTimezone(direction: .forward,
                                      referenceDay: reference,
                                      expectedDict: [.sunday :      reference.changing(day: 25),
                                                     .monday:       reference.changing(day: 26),
                                                     .tuesday:      reference.changing(day: 27),
                                                     .wednesday:    reference.changing(day: 28),
                                                     .thursday:     reference,
                                                     .friday:       reference.changing(day: 23),
                                                     .saturday:     reference.changing(day: 24)])
    }

    func testOverDSTSwitchOnBackwards() {
        let reference = DayComponents(year: 2018, month: 3, day: 27) // Tuesday
        testForEachWeekdayAndTimezone(direction: .backward,
                                      referenceDay: reference,
                                      expectedDict: [.sunday :      reference.changing(day: 25),
                                                     .monday:       reference.changing(day: 26),
                                                     .tuesday:      reference,
                                                     .wednesday:    reference.changing(day: 21),
                                                     .thursday:     reference.changing(day: 22),
                                                     .friday:       reference.changing(day: 23),
                                                     .saturday:     reference.changing(day: 24)])
    }

    // MARK: -

    private func forEachTimezone(_ closure: (Calendar) -> () ) {
        for timezoneId in TimeZone.knownTimeZoneIdentifiers {
            let tz = TimeZone(identifier: timezoneId)!
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = tz
            closure(calendar)
        }
    }

    private func forEachWeekdayAndTimezone(_ closure: (Weekday, Calendar) -> () ) {
        forEachTimezone { calendar in
            for weekday in Weekday.allDays {
                closure(weekday, calendar)
            }
        }
    }

    private func testForEachWeekdayAndTimezone(direction: Calendar.SearchDirection,
                                               referenceDay: DayComponents,
                                               expectedDict: [Weekday : DayComponents]) {
        forEachWeekdayAndTimezone { (weekday, calendar) in
            test(for: weekday,
                 calendar: calendar,
                 direction: direction,
                 referenceDay: referenceDay,
                 expectedDict: expectedDict)
        }
    }

    private func test(for weekday: Weekday,
                      calendar: Calendar,
                      direction: Calendar.SearchDirection,
                      referenceDay: DayComponents,
                      expectedDict: [Weekday : DayComponents]) {
        let foundOrNil: Date? = {
            let comps = DateComponents(calendar: calendar, timeZone: calendar.timeZone,
                                       year: referenceDay.year, month: referenceDay.month, day: referenceDay.day,
                                       hour: 17, minute: 30)
            let date = calendar.date(from: comps)
            XCTAssertNotNil(date)
            return calendar.findClosestWeekdayDate(startingFrom: date!, matching: weekday, direction: direction)
        }()
        XCTAssertNotNil(foundOrNil)
        let found = foundOrNil!

        let expectedOrNil = expectedDict[weekday]
        XCTAssertNotNil(expectedOrNil)
        let expected = expectedOrNil!

        let foundAsDateComponents = calendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .weekday],
                                                            from: found)

        let expectedAsDateComponents = DateComponents(calendar: calendar, timeZone: calendar.timeZone,
                                                      year: expected.year, month: expected.month, day: expected.day,
                                                      weekday: weekday.indexInGregorianCalendar)
        XCTAssertEqual(foundAsDateComponents, expectedAsDateComponents)
    }
}

fileprivate extension DayComponents {
    func changing(year: Int? = nil, month: Int? = nil, day: Int?) -> DayComponents {
        return DayComponents(year: year ?? self.year, month: month ?? self.month, day: day ?? self.day)
    }
}
