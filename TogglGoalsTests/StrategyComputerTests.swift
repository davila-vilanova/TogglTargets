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

        let date = try! calendar.date(from: DayComponents(year: year, month: month, day: day))
        let sc = StrategyComputer(calendar: calendar)
        sc.goal = TimeGoal(forProjectId: 0, hoursPerMonth: hoursTarget, workWeekdays: WeekdaySelection.exceptWeekend)
        let startPeriodDay = DayComponents(year: year, month: month, day: 1)
        let endPeriodDay = DayComponents(year: year, month: month, day: 28)
        sc.startPeriodDay = startPeriodDay
        sc.endPeriodDay = endPeriodDay
        sc.report = TwoPartTimeReport(projectId: 0, since: startPeriodDay, until: endPeriodDay, workedTimeUntilYesterday: TimeInterval(workedHours * 3600), workedTimeToday: 0.0)
        sc.startStrategyDay = calendar.dayComponents(from: date)

        XCTAssertEqual(sc.totalWorkdays, 20)
        XCTAssertEqual(sc.remainingWorkdays, 17)

        let accuracy = 0.01
        XCTAssertEqualWithAccuracy(sc.timeGoal, TimeInterval(hoursTarget * 3600), accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.workedTime, TimeInterval(workedHours * 3600), accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.remainingTimeToGoal, TimeInterval(69.0 * 3600), accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.dayBaseline, TimeInterval(4.0 * 3600), accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.dayBaselineAdjustedToProgress, TimeInterval(4.058823 * 3600), accuracy: accuracy)
        XCTAssertEqualWithAccuracy(sc.dayBaselineDifferential, (1.47 / 100), accuracy: accuracy)
    }
}
