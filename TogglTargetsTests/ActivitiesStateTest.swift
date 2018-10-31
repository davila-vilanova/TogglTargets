//
//  ActivitiesStateTest.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 17.02.18.
//  Copyright © 2018 davi. All rights reserved.
//

import XCTest
import Result
import ReactiveSwift

fileprivate let OutputTimeout = TimeInterval(3)

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
        var outputValue: [ActivityStatus]? = nil

        let firstOutputExpectation = expectation(description: "1st output value received")
        signalHolder = testee.output.take(first: 1).on(value: { _ in firstOutputExpectation.fulfill() })

        testee.input <~ SignalProducer(value: .executing(.syncProfile))

        wait(for: [firstOutputExpectation], timeout: OutputTimeout)

        let secondOutputExpectation = expectation(description: "test output value received")
        signalHolder = testee.output.take(first: 1).on(value: { outputValue = $0; secondOutputExpectation.fulfill() })

        testee.input <~ SignalProducer(value: .succeeded(.syncProfile))
        testee.input <~ SignalProducer(value: .executing(.syncProjects))
        testee.input <~ SignalProducer(value: .executing(.syncReports))

        wait(for: [secondOutputExpectation], timeout: OutputTimeout)

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
        var outputValue: [ActivityStatus]? = nil

        let firstOutputsExpectation = expectation(description: "First 2 output values received")
        firstOutputsExpectation.expectedFulfillmentCount = 2
        signalHolder = testee.output.take(first: 2).on(value: { _ in firstOutputsExpectation.fulfill() })

        testee.input <~ SignalProducer(value: .succeeded(.syncProfile))
        testee.input <~ SignalProducer(value: .executing(.syncProjects))
        testee.input <~ SignalProducer(value: .executing(.syncReports))

        wait(for: [firstOutputsExpectation], timeout: OutputTimeout)

        let secondOutputExpectation = expectation(description: "test output value received")
        signalHolder = testee.output.take(first: 1).on(value: { outputValue = $0; secondOutputExpectation.fulfill() })

        testee.input <~ SignalProducer(value: .succeeded(.syncProjects))

        wait(for: [secondOutputExpectation], timeout: OutputTimeout)

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


fileprivate class RelativeTimestamperLogger {
    private let startTime = Date()

    public func log(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        print("[\(String(format: "%.3f", elapsed))] [\(identifier)] \(event)")
    }
}
