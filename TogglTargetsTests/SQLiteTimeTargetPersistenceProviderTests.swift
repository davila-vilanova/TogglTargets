//
//  SQLiteTimeTargetPersistenceProviderTests.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 15.05.18.
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

private let timeoutForExpectations: TimeInterval = 1

class SQLiteTimeTargetPersistenceProviderTests: XCTestCase {

    func testStoreAndRetrieveTimeTargets() {
        let fixtureMonthly = TimeTarget(for: 4121, hoursTarget: 24, workWeekdays: .exceptWeekend)
        let fixtureWeekly = TimeTarget(for: 1381, hoursTarget: 8, workWeekdays: .wholeWeek)

        guard let store = SQLiteTimeTargetPersistenceProvider(baseDirectory: FileManager.default.temporaryDirectory,
                                                              writeTimeTargetsOn: UIScheduler())
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
