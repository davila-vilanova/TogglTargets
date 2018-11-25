//
//  TogglAPIDataCacheTest.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 30.06.18.
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

private let testProfile = Profile(id: 118030,
                                      name: "Ardilla Squirrel",
                                      email: "whatup@ardillita.me",
                                      imageUrl: nil,
                                      timezone: "Europe/Berlin",
                                      workspaces: [Workspace](),
                                      apiToken: nil)

private let testProjects: IndexedProjects = [100: Project(id: 100, name: "first", active: true, workspaceId: 1),
                                                 200: Project(id: 200, name: "second", active: true, workspaceId: 1),
                                                 300: Project(id: 300, name: "third", active: true, workspaceId: 2)]

private let timeoutForExpectations = TimeInterval(0.5)

class TogglAPIDataCacheTest: XCTestCase {

    private var persistenceProvider: TogglAPIDataPersistenceProviderMock!
    private var cache: TogglAPIDataCache!

    override func setUp() {
        super.setUp()
        persistenceProvider = TogglAPIDataPersistenceProviderMock()
        cache = TogglAPIDataCache(persistenceProvider: persistenceProvider)
    }

    override func tearDown() {
        cache = nil
        persistenceProvider = nil
        super.tearDown()
    }

    func testRetrieveNonStoredProfile() {
        let retrieved = Property(initial: nil, then: cache.retrieveProfile.values)
        cache.retrieveProfile.apply().start()
        wait(for: [persistenceProvider.retrieveProfileExpectation], timeout: timeoutForExpectations)
        XCTAssertNil(retrieved.value)
    }

    func testStoreAndRetrieveProfile() {
        cache.storeProfile <~ SignalProducer(value: testProfile)
        let retrieved = Property(initial: nil, then: cache.retrieveProfile.values)
        cache.retrieveProfile.apply().start()
        wait(for: [persistenceProvider.persistProfileExpectation, persistenceProvider.retrieveProfileExpectation],
             timeout: timeoutForExpectations, enforceOrder: true)
        XCTAssertEqual(retrieved.value, testProfile)
    }

    func testDeleteProfile() {
        cache.storeProfile <~ SignalProducer(value: testProfile)
        cache.storeProfile <~ SignalProducer(value: nil)
        let retrieved = Property(initial: nil, then: cache.retrieveProfile.values)
        cache.retrieveProfile.apply().start()
        wait(for: [persistenceProvider.persistProfileExpectation,
                   persistenceProvider.deleteProfileExpectation,
                   persistenceProvider.retrieveProfileExpectation],
             timeout: timeoutForExpectations, enforceOrder: false)
        XCTAssertNil(retrieved.value)
    }

    func testRetrieveNonStoredProjects() {
        let retrieved = Property(initial: nil, then: cache.retrieveProjects.values)
        cache.retrieveProjects.apply().start()
        wait(for: [persistenceProvider.retrieveProjectsExpectation], timeout: timeoutForExpectations)
        XCTAssertNil(retrieved.value)
    }

    func testStoreAndRetrieveProjects() {
        cache.storeProjects <~ SignalProducer(value: testProjects)
        let retrieved = Property(initial: nil, then: cache.retrieveProjects.values)
        cache.retrieveProjects.apply().start()
        wait(for: [persistenceProvider.persistProjectsExpectation, persistenceProvider.retrieveProjectsExpectation],
             timeout: timeoutForExpectations)
        XCTAssertEqual(retrieved.value, testProjects)
    }
}

private class TogglAPIDataPersistenceProviderMock: TogglAPIDataPersistenceProvider {
    fileprivate let persistProfileExpectation: XCTestExpectation
    fileprivate let retrieveProfileExpectation: XCTestExpectation
    fileprivate let deleteProfileExpectation: XCTestExpectation
    fileprivate let persistProjectsExpectation: XCTestExpectation
    fileprivate let retrieveProjectsExpectation: XCTestExpectation
    fileprivate let deleteProjectsExpectation: XCTestExpectation

    private var persistedProfile: Profile?
    private var persistedProjects: [Project]?

    init() {
        persistProfileExpectation = XCTestExpectation(description: "Persist Profile")
        retrieveProfileExpectation = XCTestExpectation(description: "Retrieve Profile")
        deleteProfileExpectation = XCTestExpectation(description: "Delete Profile")
        persistProjectsExpectation = XCTestExpectation(description: "Persist Projects")
        retrieveProjectsExpectation = XCTestExpectation(description: "Retrieve Projects")
        deleteProjectsExpectation = XCTestExpectation(description: "Delete Projects")
    }

    func persist(profile: Profile) {
        defer {
            persistProfileExpectation.fulfill()
        }
        persistedProfile = profile
    }

    func retrieveProfile() -> Profile? {
        defer {
            retrieveProfileExpectation.fulfill()
        }
        return persistedProfile
    }

    func deleteProfile() {
        defer {
            deleteProfileExpectation.fulfill()
        }
        persistedProfile = nil
    }

    func persist(projects: [Project]) {
        defer {
            persistProjectsExpectation.fulfill()
        }
        persistedProjects = projects
    }

    func retrieveProjects() -> [Project]? {
        defer {
            retrieveProjectsExpectation.fulfill()
        }
        return persistedProjects
    }

    func deleteProjects() {
        defer {
            deleteProjectsExpectation.fulfill()
        }
        persistedProjects = nil
    }
}
