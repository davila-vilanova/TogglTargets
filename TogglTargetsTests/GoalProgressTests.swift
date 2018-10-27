//
//  GoalProgressTests.swift
//  TogglGoalsTests
//
//  Created by David Dávila on 30.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest
import ReactiveSwift
import Result

fileprivate var currentDate = Date(timeIntervalSince1970: 1507731805) // 11. Oct 2017, 16:23 in Berlin
fileprivate let projectIdA: Int64 = 310
fileprivate let projectIdB: Int64 = 311
fileprivate let timeRunningEntryA = TimeInterval.from(hours: 1.5)
fileprivate let timeRunningEntryB = TimeInterval.from(hours: 2.5)
fileprivate let runningEntryProjectA = makeRunningEntry(projectId: projectIdA, runningTime: timeRunningEntryA)
fileprivate let runningEntryProjectB = makeRunningEntry(projectId: projectIdB, runningTime: timeRunningEntryB)

fileprivate let hoursPerMonthGoal = 95
fileprivate let timeTarget = TimeTarget(for: projectIdA, hoursTarget: hoursPerMonthGoal, workWeekdays: .exceptWeekend)
fileprivate let todayComponents = DayComponents(year: 2017, month: 10, day: 11)
fileprivate let tomorrowComponents = DayComponents(year: 2017, month: 10, day: 12)
fileprivate let period = Period(start: DayComponents(year: 2017, month: 10, day: 1), end: todayComponents)
fileprivate let report = TwoPartTimeReport(projectId: projectIdA,
                                           period: period,
                                           workedTimeUntilDayBeforeRequest: .from(hours: 26),
                                           workedTimeOnDayOfRequest: .from(hours: 3))

func makeRunningEntry(projectId: Int64, runningTime: TimeInterval) -> RunningEntry {
    return RunningEntry(id: 0, projectId: projectId, start: currentDate.addingTimeInterval(-runningTime), retrieved: currentDate)
}


/// This class just serves the purpose of doing all the common setup.
/// The other XCTestCase derived classes in this file inherit from this.
/// Do not include tests directly in this class, or else they will be run each
/// time the tests for any of the subclasses are run.
class GoalProgressTests: XCTestCase {
    fileprivate var goalProgress: GoalProgress!

    override func setUp() {
        super.setUp()
        goalProgress = GoalProgress()
        goalProgress.projectId <~ SignalProducer(value: projectIdA)
        goalProgress.currentDate <~ SignalProducer(value: currentDate)
        let berlinCalendar: Calendar = {
            var cal = Calendar(identifier: .iso8601)
            let ber = TimeZone(identifier: "Europe/Berlin")!
            cal.timeZone = ber
            return cal
        }()
        goalProgress.calendar <~ SignalProducer(value: berlinCalendar)
    }
}

class GoalProgressWorkDaysTests: GoalProgressTests {
    override func setUp() {
        super.setUp()
        goalProgress.timeTarget <~ SignalProducer(value: timeTarget)
        goalProgress.endGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
    }

    func testTotalWorkDays() {
        goalProgress.startGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        let totalWorkDays = MutableProperty<Int?>(nil)
        totalWorkDays <~ goalProgress.totalWorkDays
        XCTAssertEqual(totalWorkDays.value, 22)
    }

    func testRemainingWorkDays() {
        goalProgress.startStrategyDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 26))
        let remainingWorkDays = MutableProperty<Int?>(nil)
        remainingWorkDays <~ goalProgress.remainingWorkDays
        XCTAssertEqual(remainingWorkDays.value, 4)
    }
}

class GoalProgressWorkedTimeTests: GoalProgressTests {
    private let workedTimeResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        goalProgress.report <~ SignalProducer(value: report)
        workedTimeResult <~ goalProgress.workedTime
    }

    func testWorkedTimeStartingStrategyTomorrow() {
        // Calculating strategy from next work day (report.until + 1 day) should yield the full report time ...
        goalProgress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        XCTAssertEqual(workedTimeResult.value, report.workedTime)
    }

    func testWorkedTimeStartingStrategyTomorrowIncludesRunningEntryIfItBelongsToSameProject() {
        // ... plus the time from the running entry if it corresponds to the same project
        goalProgress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTimeResult.value, report.workedTime + timeRunningEntryA)
    }

    func testWorkedTimeStartingStrategyTomorrowDoesNoIncludeRunningEntryIfItDoesNotBelongToSameProject() {
        // ... though absolutely not if it corresponds to a different project
        goalProgress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectB)
        XCTAssertEqual(workedTimeResult.value, report.workedTime)
    }

    func testNilReportIsInterpretedAsZeroedTimeReportWhenStartingStrategyTomorrow() {
        goalProgress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        goalProgress.report <~ SignalProducer(value: nil)
        XCTAssertEqual(workedTimeResult.value, 0)

        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTimeResult.value, timeRunningEntryA)
    }

    func testWorkedTimeStartingStrategyToday() {
        // Calculating strategy from same day as currentDate (that is, "today", which also is the end date for the report)
        // should yield the time worked until yesterday according to the report ...
        goalProgress.startStrategyDay <~ SignalProducer(value: todayComponents)
        XCTAssertEqual(workedTimeResult.value, report.workedTimeUntilDayBeforeRequest)
    }

    func testWorkedTimeStartingStrategyTodayIgnoresRunningEntry() {
        // ... and that should be regardless of whether there is a running entry corresponding to the current project
        goalProgress.startStrategyDay <~ SignalProducer(value: todayComponents)
        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTimeResult.value, report.workedTimeUntilDayBeforeRequest)
    }

    func testNilReportIsInterpretedAsZeroedTimeReportWhenStartingStrategyToday() {
        goalProgress.startStrategyDay <~ SignalProducer(value: todayComponents)
       goalProgress.report <~ SignalProducer(value: nil)
        XCTAssertEqual(workedTimeResult.value, 0)
        // with or without time entry
        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTimeResult.value, 0)
    }

    func testTimeWorkedToday() {
        let workedTodayResult = MutableProperty<TimeInterval?>(nil)
        workedTodayResult <~ goalProgress.timeWorkedToday

        XCTAssertEqual(workedTodayResult.value, report.workedTimeOnDayOfRequest)

        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTodayResult.value, (report.workedTimeOnDayOfRequest + timeRunningEntryA))

        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectB)
        XCTAssertEqual(workedTodayResult.value, report.workedTimeOnDayOfRequest)
    }
}

class GoalProgressRemainingTimeTests: GoalProgressTests {
    private let remainingTimeResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        goalProgress.report <~ SignalProducer(value: report)
        goalProgress.timeTarget <~ SignalProducer(value: timeTarget)
        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        remainingTimeResult <~ goalProgress.remainingTimeToGoal
    }

    func testRemainingTimeStartingStrategyTomorrow() {
        // Calculating strategy from tomorrow should result in the target time minus the full time worked
        goalProgress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        XCTAssertEqual(remainingTimeResult.value, TimeInterval.from(hours: hoursPerMonthGoal) - report.workedTime - timeRunningEntryA)
    }

    func testRemainingTimeStartingStrategyToday() {
        // Calculating strategy from same day as currentDate (that is, "today", which also is the end date for the report)
        // should result in the target time minus the time worked until yesterday according to the report
        // because today's time is already part of the execution of the current strategy.
        // runningEntry should be ignored
        assert(todayComponents == report.period.end) // internal tests consistency
        goalProgress.startStrategyDay <~ SignalProducer(value: todayComponents)
        XCTAssertEqual(remainingTimeResult.value, TimeInterval.from(hours: hoursPerMonthGoal) - report.workedTimeUntilDayBeforeRequest)
    }
}

class GoalProgressDayBaselineTests: GoalProgressTests {
    private let dayBaselineResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        goalProgress.timeTarget <~ SignalProducer(value: timeTarget)
        goalProgress.startGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        goalProgress.endGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
        dayBaselineResult <~ goalProgress.dayBaseline
    }

    func testDayBaseline() {
        let totalWorkDays = 22.0
        let expectedBaseline: TimeInterval = TimeInterval.from(hours: hoursPerMonthGoal) / totalWorkDays
        XCTAssertEqual(dayBaselineResult.value, expectedBaseline)
    }
}

class GoalProgressAdjustedDayBaselineTests: GoalProgressTests {
    private let adjustedBaselineResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        goalProgress.timeTarget <~ SignalProducer(value: timeTarget)
        goalProgress.startGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        goalProgress.endGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
        goalProgress.report <~ SignalProducer(value: report)
        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        adjustedBaselineResult <~ goalProgress.dayBaselineAdjustedToProgress
    }

    func testAdjustedDayBaselineStartingStrategyTomorrow() {
        goalProgress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        let expectedRemainingTimeToGoal = TimeInterval.from(hours: hoursPerMonthGoal) - report.workedTime - timeRunningEntryA
        let remainingWorkDays = 14.0
        XCTAssertEqual(adjustedBaselineResult.value, expectedRemainingTimeToGoal / remainingWorkDays)
    }

    func testAdjustedDayBaselineStartingStrategyToday() {
        goalProgress.startStrategyDay <~ SignalProducer(value: todayComponents)
        let expectedRemainingTimeToGoal = TimeInterval.from(hours: hoursPerMonthGoal) - report.workedTimeUntilDayBeforeRequest
        let remainingWorkDays = 15.0
        XCTAssertEqual(adjustedBaselineResult.value, expectedRemainingTimeToGoal / remainingWorkDays)
    }
}

class GoalProgressBaselineDifferentialTests: GoalProgressTests {
    private let baselineDifferentialResult = MutableProperty<Double?>(nil)

    override func setUp() {
        super.setUp()
        goalProgress.timeTarget <~ SignalProducer(value: timeTarget)
        goalProgress.startGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        goalProgress.endGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
        goalProgress.report <~ SignalProducer(value: report)
        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        baselineDifferentialResult <~ goalProgress.dayBaselineDifferential
    }

    func testBaselineDifferential() {
        goalProgress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        XCTAssertNotNil(baselineDifferentialResult.value)

        let totalWorkDays = 22.0
        let remainingTimeToGoal = TimeInterval.from(hours: hoursPerMonthGoal) - report.workedTime - timeRunningEntryA
        let remainingWorkDays = 14.0
        let baseline: TimeInterval = TimeInterval.from(hours: hoursPerMonthGoal) / totalWorkDays
        let adjustedBaseline: TimeInterval = remainingTimeToGoal / remainingWorkDays
        let computedAdjustedBaseline = baseline + (baseline * baselineDifferentialResult.value!) // asserted earlier as non nil
        XCTAssertEqual(computedAdjustedBaseline, adjustedBaseline, accuracy: pow(10, -12.0)) // this test's calculation seems not quite as precise as to satisfy Double's epsilon which approaches 2.22e-16
    }
}

class GoalProgressRemainingTimeToDayBaselineTests: GoalProgressTests {
    private let remainingTodayResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        goalProgress.timeTarget <~ SignalProducer(value: timeTarget)
        goalProgress.startGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        goalProgress.endGoalDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
        goalProgress.report <~ SignalProducer(value: report)
        goalProgress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        remainingTodayResult <~ goalProgress.remainingTimeToDayBaseline
    }

    func testRemainingTimeToDayBaseline() {
        goalProgress.startStrategyDay <~ SignalProducer(value: todayComponents)

        let workedTodayResult = MutableProperty<TimeInterval?>(nil)
        workedTodayResult <~ goalProgress.timeWorkedToday
        let adjustedDayBaselineResult = MutableProperty<TimeInterval?>(nil)
        adjustedDayBaselineResult <~ goalProgress.dayBaselineAdjustedToProgress

        XCTAssertNotNil(adjustedDayBaselineResult.value)
        XCTAssertNotNil(workedTodayResult.value)
        XCTAssertEqual(remainingTodayResult.value, adjustedDayBaselineResult.value! - workedTodayResult.value!)
    }

    func testRemainingTimeToDayBaselineIsNilWhenStrategyStartsTomorrow() {
        goalProgress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)

        XCTAssertNil(remainingTodayResult.value)
    }

    func testRemainingTimeToDayBaselineZeroRatherThanNegative() {
        goalProgress.startStrategyDay <~ SignalProducer(value: todayComponents)
        let longerRunningEntry = makeRunningEntry(projectId: projectIdA, runningTime: .from(hours: 4))
        goalProgress.runningEntry <~ SignalProducer(value: longerRunningEntry)

        XCTAssertNotNil(remainingTodayResult.value)
        XCTAssertEqual(remainingTodayResult.value!, 0.0, accuracy: .ulpOfOne)
    }
}
