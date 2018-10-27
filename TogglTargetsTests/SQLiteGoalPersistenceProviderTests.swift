//
//  SQLiteGoalPersistenceProviderTests.swift
//  TogglGoalsTests
//
//  Created by David Dávila on 15.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import XCTest
import ReactiveSwift

fileprivate let timeoutForExpectations: TimeInterval = 1

class SQLiteGoalPersistenceProviderTests: XCTestCase {

    func testStoreAndRetrieveGoals() {
        let fixtureMonthly = TimeTarget(for: 4121, hoursTarget: 24, workWeekdays: .exceptWeekend)
        let fixtureWeekly = TimeTarget(for: 1381, hoursTarget: 8, workWeekdays: .wholeWeek)

        guard let store = SQLiteGoalPersistenceProvider(baseDirectory: FileManager.default.temporaryDirectory) else {
            XCTFail()
            return
        }
        store.persistGoal <~ SignalProducer([fixtureMonthly, fixtureWeekly])

        let goalsRetrievedExpectation = expectation(description: "All goals retrieved from database")
        store.allGoals.start(on: UIScheduler()).startWithValues { indexedGoals in
            goalsRetrievedExpectation.fulfill()
            XCTAssertEqual(indexedGoals[4121], fixtureMonthly)
            XCTAssertEqual(indexedGoals[1381], fixtureWeekly)
        }

        wait(for: [goalsRetrievedExpectation], timeout: timeoutForExpectations)
    }

}
