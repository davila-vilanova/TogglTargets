//
//  ActivitiesStateTest.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 17.02.18.
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
import Result
import ReactiveSwift

private let outputTimeout = TimeInterval(7)

class ActivitiesStateTest: XCTestCase {
    let scheduler = QueueScheduler()

    var testee: ActivitiesState!
    var signalHolder: Signal<[ActivityStatus], NoError>?

    override func setUp() {
        testee = ActivitiesState()
    }

    override func tearDown() {
        signalHolder = nil
        testee = nil
    }

    func testChangeFromSyncingProfileToSyncingProjectsAndReports() {
        var outputValue: [ActivityStatus]?

        let firstOutputExpectation = expectation(description: "1st output value received")
        signalHolder = testee.output.take(first: 1).on(value: { _ in firstOutputExpectation.fulfill() })

        testee.input <~ SignalProducer(value: .executing(.syncProfile))

        wait(for: [firstOutputExpectation], timeout: outputTimeout)

        let secondOutputExpectation = expectation(description: "test output value received")
        signalHolder = testee.output.take(first: 1).on(value: { outputValue = $0; secondOutputExpectation.fulfill() })

        testee.input <~ SignalProducer(value: .succeeded(.syncProfile))
        testee.input <~ SignalProducer(value: .executing(.syncProjects))
        testee.input <~ SignalProducer(value: .executing(.syncReports))

        wait(for: [secondOutputExpectation], timeout: outputTimeout)

        guard let value = outputValue else {
            XCTFail("output value is nil")
            return
        }

        XCTAssertEqual(value.count, 3)
        var iterator = value.makeIterator()
        XCTAssertEqual(iterator.next(), .succeeded(.syncProfile))
        XCTAssertEqual(iterator.next(), .executing(.syncProjects))
        XCTAssertEqual(iterator.next(), .executing(.syncReports))
        XCTAssertNil(iterator.next())
    }

    func testChangeFromSyncingProjectsAndReportsIntoSyncingReports() {
        var outputValue: [ActivityStatus]?

        let firstOutputsExpectation = expectation(description: "First 2 output values received")
        firstOutputsExpectation.expectedFulfillmentCount = 2
        signalHolder = testee.output.take(first: 2).on(value: { _ in firstOutputsExpectation.fulfill() })

        testee.input <~ SignalProducer(value: .succeeded(.syncProfile))
        testee.input <~ SignalProducer(value: .executing(.syncProjects))
        testee.input <~ SignalProducer(value: .executing(.syncReports))

        wait(for: [firstOutputsExpectation], timeout: outputTimeout)

        let secondOutputExpectation = expectation(description: "test output value received")
        signalHolder = testee.output.take(first: 1).on(value: { outputValue = $0; secondOutputExpectation.fulfill() })

        testee.input <~ SignalProducer(value: .succeeded(.syncProjects))

        wait(for: [secondOutputExpectation], timeout: outputTimeout)

        guard let value = outputValue else {
            XCTFail("output value is nil")
            return
        }

        var iterator = value.makeIterator()
        XCTAssertEqual(iterator.next(), .succeeded(.syncProjects))
        XCTAssertEqual(iterator.next(), .executing(.syncReports))
        XCTAssertNil(iterator.next())
    }
}

private class RelativeTimestamperLogger {
    private let startTime = Date()

    public func log(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        print("[\(String(format: "%.3f", elapsed))] [\(identifier)] \(event)")
    }
}
