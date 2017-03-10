//
//  StrategyComputerTests.swift
//  TogglGoals
//
//  Created by David Davila on 05.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

class StrategyComputerTests: XCTestCase {
    func testComputedValues() {
        let year = 2017
        let month = 2
        let day = 5
        let hoursTarget = 80
        let workedHours = 11

        var calendar = Calendar(identifier: .iso8601)
        let z = TimeZone(identifier: "America/Chicago")!
        calendar.timeZone = z

        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let sc = StrategyComputer(calendar: calendar, now: date)
        sc.goal = TimeGoal(forProjectId: 0, hoursPerMonth: hoursTarget, workWeekdays: WeekdaySelection.exceptWeekend)
        sc.report = TimeReport(projectId: 0, since: DateComponents(year: year, month: month, day: 1), until: DateComponents(year: year, month: month, day: 28), workedTime: TimeInterval(workedHours * 3600))

        XCTAssertEqual(sc.totalWorkdays, 20)
        XCTAssertEqual(sc.remainingFullWorkdays, 17)

        let accuracy = 0.001
        XCTAssertEqualWithAccuracy(sc.timeGoal, TimeInterval(hoursTarget * 3600), accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.workedTime, TimeInterval(workedHours * 3600), accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.remainingTimeToGoal, TimeInterval(69.0 * 3600), accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.dayBaseline, 4.0, accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.dayBaselineAdjustedToProgress, 4.058823, accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.dayBaselineDifferential, 1.47, accuracy: accuracy)
    }
}
