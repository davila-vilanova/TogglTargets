//
//  ProgressToTimeTargetTests.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 30.09.17.
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
import ReactiveSwift

private var currentDate = Date(timeIntervalSince1970: 1507731805) // 11. Oct 2017, 16:23 in Berlin
private let projectIdA: Int64 = 310
private let projectIdB: Int64 = 311
private let timeRunningEntryA = TimeInterval.from(hours: 1.5)
private let timeRunningEntryB = TimeInterval.from(hours: 2.5)
private let runningEntryProjectA = makeRunningEntry(projectId: projectIdA, runningTime: timeRunningEntryA)
private let runningEntryProjectB = makeRunningEntry(projectId: projectIdB, runningTime: timeRunningEntryB)

private let hoursPerMonthTarget = 95
private let timeTarget = TimeTarget(for: projectIdA, hoursTarget: hoursPerMonthTarget, workWeekdays: .exceptWeekend)
private let todayComponents = DayComponents(year: 2017, month: 10, day: 11)
private let tomorrowComponents = DayComponents(year: 2017, month: 10, day: 12)
private let period = Period(start: DayComponents(year: 2017, month: 10, day: 1), end: todayComponents)
private let report = TwoPartTimeReport(projectId: projectIdA,
                                           period: period,
                                           workedTimeUntilDayBeforeRequest: .from(hours: 26),
                                           workedTimeOnDayOfRequest: .from(hours: 3))

func makeRunningEntry(projectId: Int64, runningTime: TimeInterval) -> RunningEntry {
    return RunningEntry(id: 0,
                        projectId: projectId,
                        start: currentDate.addingTimeInterval(-runningTime),
                        retrieved: currentDate)
}

/// This class just serves the purpose of doing all the common setup.
/// The other XCTestCase derived classes in this file inherit from this.
/// Do not include tests directly in this class, or else they will be run each
/// time the tests for any of the subclasses are run.
class ProgressToTimeTargetTests: XCTestCase {
    fileprivate var progress: ProgressToTimeTarget!

    override func setUp() {
        super.setUp()
        progress = ProgressToTimeTarget()
        progress.projectId <~ SignalProducer(value: projectIdA)
        progress.currentDate <~ SignalProducer(value: currentDate)
        let berlinCalendar: Calendar = {
            var cal = Calendar(identifier: .iso8601)
            let ber = TimeZone(identifier: "Europe/Berlin")!
            cal.timeZone = ber
            return cal
        }()
        progress.calendar <~ SignalProducer(value: berlinCalendar)
    }
}

class WorkDaysTests: ProgressToTimeTargetTests {
    override func setUp() {
        super.setUp()
        progress.timeTarget <~ SignalProducer(value: timeTarget)
        progress.endDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
    }

    func testTotalWorkDays() {
        progress.startDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        let totalWorkDays = MutableProperty<Int?>(nil)
        totalWorkDays <~ progress.totalWorkDays
        XCTAssertEqual(totalWorkDays.value, 22)
    }

    func testRemainingWorkDays() {
        progress.startStrategyDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 26))
        let remainingWorkDays = MutableProperty<Int?>(nil)
        remainingWorkDays <~ progress.remainingWorkDays
        XCTAssertEqual(remainingWorkDays.value, 4)
    }
}

class WorkedTimeTests: ProgressToTimeTargetTests {
    private let workedTimeResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        progress.report <~ SignalProducer(value: report)
        workedTimeResult <~ progress.workedTime
    }

    func testWorkedTimeStartingStrategyTomorrow() {
        // Calculating strategy from next work day (report.until + 1 day) should yield the full report time ...
        progress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        XCTAssertEqual(workedTimeResult.value, report.workedTime)
    }

    func testWorkedTimeStartingStrategyTomorrowIncludesRunningEntryIfItBelongsToSameProject() {
        // ... plus the time from the running entry if it corresponds to the same project
        progress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTimeResult.value, report.workedTime + timeRunningEntryA)
    }

    func testWorkedTimeStartingStrategyTomorrowDoesNoIncludeRunningEntryIfItDoesNotBelongToSameProject() {
        // ... though absolutely not if it corresponds to a different project
        progress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        progress.runningEntry <~ SignalProducer(value: runningEntryProjectB)
        XCTAssertEqual(workedTimeResult.value, report.workedTime)
    }

    func testNilReportIsInterpretedAsZeroedTimeReportWhenStartingStrategyTomorrow() {
        progress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        progress.report <~ SignalProducer(value: nil)
        XCTAssertEqual(workedTimeResult.value, 0)

        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTimeResult.value, timeRunningEntryA)
    }

    func testWorkedTimeStartingStrategyToday() {
        // Calculating strategy from same day as currentDate (that is, "today", which also is the end date for the
        // report) should yield the time worked until yesterday according to the report ...
        progress.startStrategyDay <~ SignalProducer(value: todayComponents)
        XCTAssertEqual(workedTimeResult.value, report.workedTimeUntilDayBeforeRequest)
    }

    func testWorkedTimeStartingStrategyTodayIgnoresRunningEntry() {
        // ... and that should be regardless of whether there is a running entry corresponding to the current project
        progress.startStrategyDay <~ SignalProducer(value: todayComponents)
        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTimeResult.value, report.workedTimeUntilDayBeforeRequest)
    }

    func testNilReportIsInterpretedAsZeroedTimeReportWhenStartingStrategyToday() {
        progress.startStrategyDay <~ SignalProducer(value: todayComponents)
       progress.report <~ SignalProducer(value: nil)
        XCTAssertEqual(workedTimeResult.value, 0)
        // with or without time entry
        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTimeResult.value, 0)
    }

    func testTimeWorkedToday() {
        let workedTodayResult = MutableProperty<TimeInterval?>(nil)
        workedTodayResult <~ progress.timeWorkedToday

        XCTAssertEqual(workedTodayResult.value, report.workedTimeOnDayOfRequest)

        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        XCTAssertEqual(workedTodayResult.value, (report.workedTimeOnDayOfRequest + timeRunningEntryA))

        progress.runningEntry <~ SignalProducer(value: runningEntryProjectB)
        XCTAssertEqual(workedTodayResult.value, report.workedTimeOnDayOfRequest)
    }
}

class RemainingTimeTests: ProgressToTimeTargetTests {
    private let remainingTimeResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        progress.report <~ SignalProducer(value: report)
        progress.timeTarget <~ SignalProducer(value: timeTarget)
        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        remainingTimeResult <~ progress.remainingTimeToTarget
    }

    func testRemainingTimeStartingStrategyTomorrow() {
        // Calculating strategy from tomorrow should result in the target time minus the full time worked
        progress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        XCTAssertEqual(remainingTimeResult.value,
                       TimeInterval.from(hours: hoursPerMonthTarget) - report.workedTime - timeRunningEntryA)
    }

    func testRemainingTimeStartingStrategyToday() {
        // Calculating strategy from same day as currentDate (that is, "today", which also is the end date for the
        // report) should result in the target time minus the time worked until yesterday according to the report
        // because today's time is already part of the execution of the current strategy.
        // runningEntry should be ignored
        assert(todayComponents == report.period.end) // internal tests consistency
        progress.startStrategyDay <~ SignalProducer(value: todayComponents)
        XCTAssertEqual(remainingTimeResult.value,
                       TimeInterval.from(hours: hoursPerMonthTarget) - report.workedTimeUntilDayBeforeRequest)
    }
}

class DayBaselineTests: ProgressToTimeTargetTests {
    private let dayBaselineResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        progress.timeTarget <~ SignalProducer(value: timeTarget)
        progress.startDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        progress.endDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
        dayBaselineResult <~ progress.dayBaseline
    }

    func testDayBaseline() {
        let totalWorkDays = 22.0
        let expectedBaseline: TimeInterval = TimeInterval.from(hours: hoursPerMonthTarget) / totalWorkDays
        XCTAssertEqual(dayBaselineResult.value, expectedBaseline)
    }
}

class AdjustedDayBaselineTests: ProgressToTimeTargetTests {
    private let adjustedBaselineResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        progress.timeTarget <~ SignalProducer(value: timeTarget)
        progress.startDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        progress.endDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
        progress.report <~ SignalProducer(value: report)
        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        adjustedBaselineResult <~ progress.dayBaselineAdjustedToProgress
    }

    func testAdjustedDayBaselineStartingStrategyTomorrow() {
        progress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        let expectedRemainingTime =
            TimeInterval.from(hours: hoursPerMonthTarget) - report.workedTime - timeRunningEntryA
        let remainingWorkDays = 14.0
        XCTAssertEqual(adjustedBaselineResult.value, expectedRemainingTime / remainingWorkDays)
    }

    func testAdjustedDayBaselineStartingStrategyToday() {
        progress.startStrategyDay <~ SignalProducer(value: todayComponents)
        let expectedRemainingTime =
            TimeInterval.from(hours: hoursPerMonthTarget) - report.workedTimeUntilDayBeforeRequest
        let remainingWorkDays = 15.0
        XCTAssertEqual(adjustedBaselineResult.value, expectedRemainingTime / remainingWorkDays)
    }
}

class BaselineDifferentialTests: ProgressToTimeTargetTests {
    private let baselineDifferentialResult = MutableProperty<Double?>(nil)

    override func setUp() {
        super.setUp()
        progress.timeTarget <~ SignalProducer(value: timeTarget)
        progress.startDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        progress.endDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
        progress.report <~ SignalProducer(value: report)
        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        baselineDifferentialResult <~ progress.dayBaselineDifferential
    }

    func testBaselineDifferential() {
        progress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)
        XCTAssertNotNil(baselineDifferentialResult.value)

        let totalWorkDays = 22.0
        let remainingTimeToTarget =
            TimeInterval.from(hours: hoursPerMonthTarget) - report.workedTime - timeRunningEntryA
        let remainingWorkDays = 14.0
        let baseline: TimeInterval = TimeInterval.from(hours: hoursPerMonthTarget) / totalWorkDays
        let adjustedBaseline: TimeInterval = remainingTimeToTarget / remainingWorkDays
        let computedAdjustedBaseline =
            baseline + (baseline * baselineDifferentialResult.value!) // asserted earlier as non nil

        // this test's calculation seems not quite as precise as to satisfy Double's epsilon which approaches 2.22e-16
        XCTAssertEqual(computedAdjustedBaseline, adjustedBaseline, accuracy: pow(10, -12.0))
    }
}

class RemainingTimeToDayBaselineTests: ProgressToTimeTargetTests {
    private let remainingTodayResult = MutableProperty<TimeInterval?>(nil)

    override func setUp() {
        super.setUp()
        progress.timeTarget <~ SignalProducer(value: timeTarget)
        progress.startDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 1))
        progress.endDay <~ SignalProducer(value: DayComponents(year: 2017, month: 10, day: 31))
        progress.report <~ SignalProducer(value: report)
        progress.runningEntry <~ SignalProducer(value: runningEntryProjectA)
        remainingTodayResult <~ progress.remainingTimeToDayBaseline
    }

    func testRemainingTimeToDayBaseline() {
        progress.startStrategyDay <~ SignalProducer(value: todayComponents)

        let workedTodayResult = MutableProperty<TimeInterval?>(nil)
        workedTodayResult <~ progress.timeWorkedToday
        let adjustedDayBaselineResult = MutableProperty<TimeInterval?>(nil)
        adjustedDayBaselineResult <~ progress.dayBaselineAdjustedToProgress

        XCTAssertNotNil(adjustedDayBaselineResult.value)
        XCTAssertNotNil(workedTodayResult.value)
        XCTAssertEqual(remainingTodayResult.value, adjustedDayBaselineResult.value! - workedTodayResult.value!)
    }

    func testRemainingTimeToDayBaselineIsNilWhenStrategyStartsTomorrow() {
        progress.startStrategyDay <~ SignalProducer(value: tomorrowComponents)

        XCTAssertNil(remainingTodayResult.value)
    }

    func testRemainingTimeToDayBaselineZeroRatherThanNegative() {
        progress.startStrategyDay <~ SignalProducer(value: todayComponents)
        let longerRunningEntry = makeRunningEntry(projectId: projectIdA, runningTime: .from(hours: 4))
        progress.runningEntry <~ SignalProducer(value: longerRunningEntry)

        XCTAssertNotNil(remainingTodayResult.value)
        XCTAssertEqual(remainingTodayResult.value!, 0.0, accuracy: .ulpOfOne)
    }
}
