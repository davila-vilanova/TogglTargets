//
//  SQLiteTimeTargetPersistenceProviderTests.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 15.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import XCTest
import ReactiveSwift

private let timeoutForExpectations: TimeInterval = 1

class SQLiteTimeTargetPersistenceProviderTests: XCTestCase {

    func testStoreAndRetrieveTimeTargets() {
        let fixtureMonthly = TimeTarget(for: 4121, hoursTarget: 24, workWeekdays: .exceptWeekend)
        let fixtureWeekly = TimeTarget(for: 1381, hoursTarget: 8, workWeekdays: .wholeWeek)

        guard let store = SQLiteTimeTargetPersistenceProvider(baseDirectory: FileManager.default.temporaryDirectory)
            else {
                XCTFail("The database file cannot be opened and cannot be created")
                return
        }
        store.persistTimeTarget <~ SignalProducer([fixtureMonthly, fixtureWeekly])

        let timeTargetsRetrievedExpectation = expectation(description: "All time targets retrieved from database")
        store.allTimeTargets.producer.start(on: UIScheduler()).startWithValues { indexedTargets in
            timeTargetsRetrievedExpectation.fulfill()
            XCTAssertEqual(indexedTargets[4121], fixtureMonthly)
            XCTAssertEqual(indexedTargets[1381], fixtureWeekly)
        }

        wait(for: [timeTargetsRetrievedExpectation], timeout: timeoutForExpectations)
    }

}
