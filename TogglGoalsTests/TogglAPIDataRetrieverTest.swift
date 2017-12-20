//
//  TogglAPIDataRetrieverTest.swift
//  TogglGoalsTests
//
//  Created by David Dávila on 20.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest
import Result
import ReactiveSwift

fileprivate let dummyAPIToken = "8a7f2049ed"
fileprivate let testCredential = TogglAPITokenCredential(apiToken: dummyAPIToken)!
fileprivate let testReportPeriod = Period(start: DayComponents(year: 2017, month: 12, day: 1), end: DayComponents(year: 2017, month: 12, day: 31))

fileprivate let testProfile = Profile(id: 118030,
                                      name: "Ardilla Squirrel",
                                      email: "whatup@ardillita.me",
                                      imageUrl: nil,
                                      timezone: "Europe/Berlin",
                                      workspaces: [Workspace(id: 1, name: "A"),
                                                   Workspace(id: 2, name: "B")],
                                      apiToken: dummyAPIToken)

fileprivate let testProjects: IndexedProjects = [100 : Project(id: 100, name: "first", active: true, workspaceId: 1),
                                                 200: Project(id: 200, name: "second", active: true, workspaceId: 1),
                                                 300 : Project(id: 300, name: "third", active: true, workspaceId: 2)]

fileprivate let testReports: IndexedTwoPartTimeReports =
    [ 100 : TwoPartTimeReport(projectId: 100, period: testReportPeriod, workedTimeUntilDayBeforeRequest: 7200, workedTimeOnDayOfRequest: 2100),
      200 : TwoPartTimeReport(projectId: 200, period: testReportPeriod, workedTimeUntilDayBeforeRequest: 3812, workedTimeOnDayOfRequest: 0),
      300 : TwoPartTimeReport(projectId: 300, period: testReportPeriod, workedTimeUntilDayBeforeRequest: 0, workedTimeOnDayOfRequest: 1800)]

let expectationsTimeout = TimeInterval(1.0)

class TogglAPIDataRetrieverTest: XCTestCase {

    var retrieveProfileNetworkAction: RetrieveProfileNetworkAction!
    var retrieveProfileCacheAction: RetrieveProfileCacheAction!
    var storeProfileCacheAction: StoreProfileCacheAction!
    var retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction!
    var retrieveReportsNetworkAction: RetrieveReportsNetworkAction!
    var retrieveRunningEntryAction: RetrieveRunningEntryNetworkAction!


    var dataRetriever: CachedTogglAPIDataRetriever!

    var retrievedProfile: Property<Profile?>!
    var retrievedProjects: Property<IndexedProjects?>!
    var retrievedReports: Property<IndexedTwoPartTimeReports?>!
    var retrievedRunningEntry: Property<RunningEntry?>!
    var lastError: Property<APIAccessError?>!

    override func setUp() {
        super.setUp()

        // Set up default actions

        retrieveProfileNetworkAction = RetrieveProfileNetworkAction { _ in
            return SignalProducer(value: testProfile)
        }
        retrieveProfileCacheAction = RetrieveProfileCacheAction { _ in SignalProducer(value: nil) }
        storeProfileCacheAction = StoreProfileCacheAction { _ in SignalProducer.empty }

        retrieveProjectsNetworkAction = RetrieveProjectsNetworkAction { workspaceIDs in
            // Return empty projects if the workspace IDs don't match the expected ones
            guard Set<Int64>(workspaceIDs) == Set<Int64>(testProfile.workspaces.map { $0.id }) else {
                return SignalProducer(value: IndexedProjects())
            }
            return SignalProducer(value: testProjects)
        }

        retrieveReportsNetworkAction = RetrieveReportsNetworkAction { (workspaceIDs, period) in
            // Return empty reports if the workspace IDs don't match the expected ones
            guard Set<Int64>(workspaceIDs) == Set<Int64>(testProfile.workspaces.map { $0.id }) else {
                return SignalProducer(value: IndexedTwoPartTimeReports())
            }
            return SignalProducer(value: testReports)
        }

        retrieveRunningEntryAction = RetrieveRunningEntryNetworkAction { _ in SignalProducer(value: nil) }


        // Clear data retriever and properties that must be reset by `makeDataRetriever()`

        dataRetriever = nil
        retrievedProfile = nil
        retrievedProjects = nil
        retrievedReports = nil
        retrievedRunningEntry = nil
        lastError = nil

    }

    private func makeDataRetriever() {
        dataRetriever = CachedTogglAPIDataRetriever(retrieveProfileNetworkAction: retrieveProfileNetworkAction,
                                                    retrieveProfileCacheAction: retrieveProfileCacheAction,
                                                    storeProfileCacheAction: storeProfileCacheAction,
                                                    retrieveProjectsNetworkActionMaker: { [unowned self] _ in self.retrieveProjectsNetworkAction },
                                                    retrieveReportsNetworkActionMaker: { [unowned self] _ in self.retrieveReportsNetworkAction },
                                                    retrieveRunningEntryNetworkAction: retrieveRunningEntryAction)
        retrievedProfile = Property(initial: nil, then: dataRetriever.profile.producer)
        retrievedProjects = Property(initial: nil, then: dataRetriever.projects.producer)
        retrievedReports = Property(initial: nil, then: dataRetriever.reports.producer)
        retrievedRunningEntry = Property(initial: nil, then: dataRetriever.runningEntry.producer)
        lastError = Property(initial: nil, then: dataRetriever.errors.producer)
    }

    private func feedAPICredentialIntoDataRetriever() {
        dataRetriever.apiCredential <~ SignalProducer<TogglAPICredential, NoError>(value: testCredential)
    }

    func testProfileIsRetrievedWhenAPICredentialBecomesAvailable() {
        makeDataRetriever()
        XCTAssertNil(retrievedProfile.value)
        let retrievalExpectation = expectation(description: "Profile must be retrieved.")
        retrievedProfile.producer.skipNil().startWithValues {
            XCTAssertEqual(testProfile, $0)
            retrievalExpectation.fulfill()
        }
        feedAPICredentialIntoDataRetriever()
        wait(for: [retrievalExpectation], timeout: expectationsTimeout)
    }

    func testProjectsAreRetrievedWhenWorkspaceIDsBecomeAvailable() {
        makeDataRetriever()
        XCTAssertNil(retrievedProjects.value)
        let retrievalExpectation = expectation(description: "Projects must be retrieved.")
        retrievedProjects.producer.skipNil().startWithValues {
            XCTAssertEqual(testProjects, $0)
            retrievalExpectation.fulfill()
        }
        feedAPICredentialIntoDataRetriever()
        wait(for: [retrievalExpectation], timeout: expectationsTimeout)
    }

}

