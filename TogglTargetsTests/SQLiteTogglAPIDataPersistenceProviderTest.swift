//
//  SQLiteTogglAPIDataPersistenceProviderTest.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 29.06.18.
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

private let testProfile = Profile(id: 118030,
                                      name: "Ardilla Squirrel",
                                      email: "whatup@ardillita.me",
                                      imageUrl: nil,
                                      timezone: "Europe/Berlin",
                                      workspaces: [Workspace](),
                                      apiToken: nil)

private let testProjects: [Project] = [Project(id: 100, name: "first", active: true, workspaceId: 1),
                                           Project(id: 200, name: "second", active: true, workspaceId: 1),
                                           Project(id: 300, name: "third", active: true, workspaceId: 2)]

class SQLiteTogglAPIDataPersistenceProviderTest: XCTestCase { // swiftlint:disable:this type_name

    var persistenceProvider: TogglAPIDataPersistenceProvider?

    override func setUp() {
        super.setUp()

        persistenceProvider =
            SQLiteTogglAPIDataPersistenceProvider(baseDirectory: FileManager.default.temporaryDirectory)
        guard persistenceProvider != nil else {
            XCTFail("The database file cannot be opened and cannot be created")
            return
        }

        XCTAssertNil(persistenceProvider!.retrieveProfile())
        XCTAssertNil(persistenceProvider!.retrieveProjects())
    }

    override func tearDown() {
        persistenceProvider?.deleteProfile()
        persistenceProvider?.deleteProjects()
        persistenceProvider = nil
        super.tearDown()
    }

    func testProfilePersistence() {
        persistenceProvider!.persist(profile: testProfile)
        let retrieved = persistenceProvider!.retrieveProfile()
        XCTAssertEqual(retrieved, testProfile)
    }

    func testProjectsPersistence() {
        persistenceProvider!.persist(projects: testProjects)
        let retrieved = persistenceProvider!.retrieveProjects()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, testProjects.count)
        for project in testProjects {
            let match = retrieved?.first(where: { (candidate) -> Bool in
                return candidate.id == project.id &&
                    candidate.name == project.name &&
                    candidate.workspaceId == project.workspaceId
            })
            XCTAssertNotNil(match, "Can't find a match for \(project)")
        }
    }

    func testStoringProjectsIsNotAccumulative() {
        persistenceProvider!.persist(projects: testProjects)
        let subset = [testProjects[0], testProjects[1]]
        persistenceProvider!.persist(projects: subset)
        let retrieved = persistenceProvider!.retrieveProjects()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, subset.count)
    }

    func testNewProjectValuesOverwriteOldOnes() {
        persistenceProvider!.persist(projects: testProjects)
        let overwritingValues = [Project(id: 100, name: "primero", active: true, workspaceId: 1),
                                 Project(id: 200, name: "segundo", active: true, workspaceId: 1),
                                 Project(id: 300, name: "tercero", active: true, workspaceId: 2)]

        persistenceProvider!.persist(projects: overwritingValues)
        let retrieved = persistenceProvider!.retrieveProjects()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, overwritingValues.count)
        for project in overwritingValues {
            let match = retrieved?.first(where: { (candidate) -> Bool in
                return candidate.id == project.id &&
                    candidate.name == project.name &&
                    candidate.workspaceId == project.workspaceId
            })
            XCTAssertNotNil(match, "Can't find a match for \(project)")
        }
    }

    func testProfileDeletion() {
        persistenceProvider!.persist(profile: testProfile)
        XCTAssertNotNil(persistenceProvider!.retrieveProfile())

        persistenceProvider!.deleteProfile()
        XCTAssertNil(persistenceProvider!.retrieveProfile())
    }

    func testProjectsDeletion() {
        persistenceProvider!.persist(projects: testProjects)
        XCTAssertNotNil(persistenceProvider!.retrieveProjects())

        persistenceProvider!.deleteProjects()
        XCTAssertNil(persistenceProvider!.retrieveProjects())
    }
}
