//
//  MakeRetrieveProjectsNetworkActionTest.swift
//  TogglGoalsTests
//
//  Created by David Dávila on 23.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest
import ReactiveSwift

let timeoutForExpectations = TimeInterval(1.0)

class MakeRetrieveProjectsNetworkActionTest: XCTestCase {

    private let projectsFixture = projectsByWorkspaces()

    private var networkRetriever: TogglAPINetworkRetriever<[Project]>!
    
    private var indexedNetworkRetrieverExpectations = [WorkspaceID : XCTestExpectation]()
    private var networkRetrieverExpectations: [XCTestExpectation] {
        return indexedNetworkRetrieverExpectations.map { $1 }
    }

    var retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction!

    // The exact URLSession value does not matter for the scope of this test case,
    // only whether it's a nil value or some URLSession value.
    let urlSession = MutableProperty<URLSession?>(URLSession.shared)


    override func setUp() {
        super.setUp()
        
        for wid in workspaceIDs {
            indexedNetworkRetrieverExpectations[wid] = expectation(description: "networkRetriever invocation expectation for workspace ID: \(wid)")
        }
        networkRetriever = { [projectsFixture, expectations = indexedNetworkRetrieverExpectations] (endpoint, _) in
            guard let wid = endpoint.containedWorkspaceID() else {
                XCTFail("Endpoint does not include any of the workspace IDs in the fixture.")
                fatalError()
            }
            guard let projects = projectsFixture[wid] else {
                XCTFail("Project not present for workspace ID \(wid)")
                fatalError()
            }
            guard let expectation = expectations[wid] else {
                XCTFail("Expectation not present for workspace ID \(wid)")
                fatalError()
            }
            expectation.fulfill()
            return SignalProducer(value: projects)
        }

        let actionState = Property(initial: nil, then: urlSession.producer)
        retrieveProjectsNetworkAction = makeRetrieveProjectsNetworkAction(actionState, networkRetriever)
    }
    
    override func tearDown() {
        indexedNetworkRetrieverExpectations = [WorkspaceID : XCTestExpectation]()
        networkRetriever = nil
        super.tearDown()
    }
    
    func testNetworkRetrieverIsInvokedForAllWorkspaceIDs() {
        retrieveProjectsNetworkAction.apply(workspaceIDs).start()
        wait(for: networkRetrieverExpectations, timeout: timeoutForExpectations)
    }

    func testProjectsFromAllWorkspacesAreCombinedAndIndexed() {
        let indexedFixtureProjects: IndexedProjects = { [projectsFixture] in
            var indexed = IndexedProjects()
            for (_, projects) in projectsFixture {
                for project in projects {
                    indexed[project.id] = project
                }
            }
            return indexed
        }()

        let valueExpectation = expectation(description: "retrieveProjectsNetworkAction value emitted")

        retrieveProjectsNetworkAction.values.producer.startWithValues { [projectsFixture, indexedFixtureProjects] (indexedOutputProjects) in
            defer {
                valueExpectation.fulfill()
            }

            XCTAssertEqual(indexedOutputProjects.count, indexedFixtureProjects.count)

            for (outputProjectId, outputProject) in indexedOutputProjects {
                XCTAssertEqual(outputProjectId, outputProject.id)
                guard let fixtureProject = indexedFixtureProjects[outputProjectId] else {
                    XCTFail("No corresponding fixture project found for output project ID \(outputProjectId)")
                    break
                }
                XCTAssertEqual(outputProject, fixtureProject)
            }
        }

        retrieveProjectsNetworkAction.apply(workspaceIDs).start()
        wait(for: networkRetrieverExpectations + [valueExpectation], timeout: timeoutForExpectations)
    }
}

fileprivate let workspaceIDs: [WorkspaceID] = [823, 172, 200]
fileprivate extension String {
    func containedWorkspaceID() -> WorkspaceID? {
        for wid in workspaceIDs {
            if self.contains(String(describing: wid)) {
                return wid
            }
        }
        return nil
    }
}

fileprivate let jsonStringWid823 = """
[
{
"id": 13,
"wid": 823,
"name": "Project 13",
"active": true,
},
{
"id": 28,
"wid": 823,
"name": "Project 28",
"active": true,
},
{
"id": 22,
"wid": 823,
"name": "Project 22",
"active": true,
}
]
"""

fileprivate let jsonStringWid172 = """
[
{
"id": 34,
"wid": 172,
"name": "Project 34",
"active": true,
},
{
"id": 48,
"wid": 172,
"name": "Project 48",
"active": true,
},
{
"id": 49,
"wid": 172,
"name": "Project 49",
"active": true,
}
]
"""

fileprivate let jsonStringWid200 = """
[
{
"id": 53,
"wid": 200,
"name": "Project 53",
"active": true,
},
{
"id": 56,
"wid": 200,
"name": "Project 56",
"active": true,
},
{
"id": 99,
"wid": 200,
"name": "Project 99",
"active": true,
}
]
"""

fileprivate func projectsByWorkspaces() -> [WorkspaceID : [Project]] {
    let jsonStringsByWorkspaces: [WorkspaceID : String] = [823 : jsonStringWid823,
                                                           172 : jsonStringWid172,
                                                           200 : jsonStringWid200]
    var projectsByWorkspaces = [WorkspaceID : [Project]]()
    for wid in workspaceIDs {
        guard let jsonString = jsonStringsByWorkspaces[wid],
            let jsonData = jsonString.data(using: .utf8),
            let projects = try? JSONDecoder().decode([Project].self, from: jsonData) else {
                XCTFail("Fixture data is not properly set up.")
                fatalError()
        }
        for project in projects {
            XCTAssertEqual(project.workspaceId, wid as WorkspaceID?, "Fixture is not congruent.")
        }
        projectsByWorkspaces[wid] = projects
    }
    return projectsByWorkspaces
}

