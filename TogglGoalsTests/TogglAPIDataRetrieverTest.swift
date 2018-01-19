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
fileprivate let firstDayOfPeriod = DayComponents(year: 2017, month: 12, day: 1)
fileprivate let yesterday = DayComponents(year: 2017, month: 12, day: 14)
fileprivate let today = DayComponents(year: 2017, month: 12, day: 15)
fileprivate let twoPartReportPeriods = TwoPartTimeReportPeriod(scope: testReportPeriod, previousToDayOfRequest: Period(start: firstDayOfPeriod, end: yesterday), dayOfRequest: today)


fileprivate let testProfile = Profile(id: 118030,
                                      name: "Ardilla Squirrel",
                                      email: "whatup@ardillita.me",
                                      imageUrl: nil,
                                      timezone: "Europe/Berlin",
                                      workspaces: [Workspace(id: 1, name: "A"),
                                                   Workspace(id: 2, name: "B")],
                                      apiToken: dummyAPIToken)

fileprivate let testProjects: IndexedProjects = [100 : Project(id: 100, name: "first", active: true, workspaceId: 1),
                                                 200 : Project(id: 200, name: "second", active: true, workspaceId: 1),
                                                 300 : Project(id: 300, name: "third", active: true, workspaceId: 2)]

fileprivate let testReports: IndexedTwoPartTimeReports =
    [ 100 : TwoPartTimeReport(projectId: 100, period: testReportPeriod, workedTimeUntilDayBeforeRequest: 7200, workedTimeOnDayOfRequest: 2100),
      200 : TwoPartTimeReport(projectId: 200, period: testReportPeriod, workedTimeUntilDayBeforeRequest: 3812, workedTimeOnDayOfRequest: 0),
      300 : TwoPartTimeReport(projectId: 300, period: testReportPeriod, workedTimeUntilDayBeforeRequest: 0, workedTimeOnDayOfRequest: 1800)]

fileprivate let testRunningEntry: RunningEntry = {
    let todayDate = try! Calendar.iso8601.date(from: today)
    let hour: TimeInterval = 3600
    return RunningEntry(id: 8110, projectId: 200, start: todayDate + (8 * hour), retrieved: todayDate + (9 * hour))
}()

fileprivate let testUnderlyingError = NSError(domain: "TogglAPIDataRetrieverTest", code: -4, userInfo: nil)
fileprivate let testError = APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError)
fileprivate func equalsTestError(_ candidate: APIAccessError) -> Bool {
    switch candidate {
    case .loadingSubsystemError(let underlying):
        let nsError = underlying as NSError
        return nsError.domain == testUnderlyingError.domain
            && nsError.code == testUnderlyingError.code
    default: return false
    }
}

fileprivate let timeoutForExpectations = TimeInterval(1.0)

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
    var lastActivity: Property<ActivityStatus?>!
    var lastError: Property<APIAccessError?>!


    // MARK: - Set up

    override func setUp() {
        super.setUp()

        // Set up default mock actions

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

        retrieveRunningEntryAction = RetrieveRunningEntryNetworkAction { _ in SignalProducer(value: testRunningEntry) }


        // Clear data retriever and properties that must be reset by `makeDataRetriever()`

        dataRetriever = nil
        retrievedProfile = nil
        retrievedProjects = nil
        retrievedReports = nil
        retrievedRunningEntry = nil
        lastActivity = nil
        lastError = nil
    }

    private func makeDataRetriever() {
        dataRetriever = CachedTogglAPIDataRetriever(retrieveProfileNetworkActionMaker: { [action = retrieveProfileNetworkAction!] _ in action },
                                                    retrieveProfileCacheAction: retrieveProfileCacheAction,
                                                    storeProfileCacheAction: storeProfileCacheAction,
                                                    retrieveProjectsNetworkActionMaker: { [action = retrieveProjectsNetworkAction!] _ in action },
                                                    retrieveReportsNetworkActionMaker: { [action = retrieveReportsNetworkAction!] _ in action },
                                                    retrieveRunningEntryNetworkActionMaker: { [action = retrieveRunningEntryAction!] _ in action })
        retrievedProfile = Property(initial: nil, then: dataRetriever.profile.producer)
        retrievedProjects = Property(initial: nil, then: dataRetriever.projects.producer)
        retrievedReports = Property(initial: nil, then: dataRetriever.reports.producer)
        retrievedRunningEntry = Property(initial: nil, then: dataRetriever.runningEntry.producer)
        lastActivity = Property(initial: nil, then: dataRetriever.status)
        lastError = Property(initial: nil, then: dataRetriever.status.map { $0.error }.skipNil())
    }

    private func feedAPICredentialIntoDataRetriever() {
        dataRetriever.apiCredential <~ SignalProducer<TogglAPICredential, NoError>(value: testCredential)
    }

    private func feedTwoPartPeriodIntoDataRetriever() {
        self.dataRetriever.twoPartReportPeriod <~ SignalProducer(value: twoPartReportPeriods)
    }


    // MARK: - Test basic retrieval

    func testProfileIsRetrievedWhenAPICredentialBecomesAvailable() {
        testRetrieval(of: retrievedProfile, satisfying: { XCTAssertEqual($0, testProfile) }, after: feedAPICredentialIntoDataRetriever)
    }

    func testRunningEntryIsRetrievedWhenAPICredentialBecomesAvailable() {
        testRetrieval(of: retrievedRunningEntry, satisfying: { XCTAssertEqual($0, testRunningEntry) }, after: feedAPICredentialIntoDataRetriever)
    }

    func testProjectsAreRetrievedWhenWorkspaceIDsBecomeAvailable() {
        testRetrieval(of: retrievedProjects, satisfying: { XCTAssertEqual($0, testProjects) }, after: feedAPICredentialIntoDataRetriever)
    }

    func testReportsAreRetrievedWhenWorkspaceIDsAndPeriodsBecomeAvailable() {
        testRetrieval(of: retrievedReports, satisfying: { XCTAssertEqual($0, testReports) }) { [unowned self] in
            self.feedAPICredentialIntoDataRetriever()
            self.feedTwoPartPeriodIntoDataRetriever()
        }
    }

    func testRetrieveRunningEntryOnDemand() {
        testRetrieval(of: retrievedRunningEntry, satisfying: {
            XCTAssertEqual($0.id, testRunningEntry.id)
            XCTAssertEqual($0.projectId, testRunningEntry.projectId)
            XCTAssertEqual($0.start, testRunningEntry.start)
            XCTAssertEqual($0.retrieved, testRunningEntry.retrieved)
        }) { [unowned self] in
            self.dataRetriever.updateRunningEntry <~ SignalProducer(value: ())
        }
    }

    private func testRetrieval<T>(of propertyProvider: @autoclosure () -> Property<T?>, satisfying test: @escaping (T) -> (), after trigger: () -> ()) {
        makeDataRetriever()
        // Property is inside an autoclosure because it becomes non-nil only after `makeDataRetriever()` is invoked.
        let property = propertyProvider()
        XCTAssertNil(property.value)
        XCTAssertNil(lastError.value)
        let retrievalExpectation = expectation(description: "Expecting incoming non-nil value for \(property)")
        property.producer.skipNil().startWithValues {
            test($0)
            retrievalExpectation.fulfill()
        }

        trigger()

        wait(for: [retrievalExpectation], timeout: timeoutForExpectations)
        XCTAssertNil(lastError.value)
    }

    func testRefreshAllData() {
        makeDataRetriever()
        XCTAssertNil(retrievedProfile.value)
        XCTAssertNil(retrievedProjects.value)
        XCTAssertNil(retrievedReports.value)
        XCTAssertNil(retrievedRunningEntry.value)
        XCTAssertNil(lastError.value)

        func retrieveTwiceExpectations(for entityName: String) -> (first: XCTestExpectation, second: XCTestExpectation) {
            let once = XCTestExpectation(description: "\(entityName) must be retrieved at least once.")
            once.expectedFulfillmentCount = 1
            once.assertForOverFulfill = false

            let twice = XCTestExpectation(description: "\(entityName) must be retrieved exactly twice.")
            twice.expectedFulfillmentCount = 2
            twice.assertForOverFulfill = true

            return (first: once, second: twice)
        }

        let profileExpectations = retrieveTwiceExpectations(for: "Profile")
        let projectsExpectations = retrieveTwiceExpectations(for: "Projects")
        let reportsExpectations = retrieveTwiceExpectations(for: "Reports")
        let runningEntryExpectations = retrieveTwiceExpectations(for: "Running Entry")

        retrievedProfile.producer.skipNil().startWithValues {
            XCTAssertEqual($0, testProfile)
            profileExpectations.first.fulfill()
            profileExpectations.second.fulfill()
        }

        retrievedProjects.producer.skipNil().startWithValues {
            XCTAssertEqual($0, testProjects)
            projectsExpectations.first.fulfill()
            projectsExpectations.second.fulfill()
        }

        retrievedReports.producer.skipNil().startWithValues {
            XCTAssertEqual($0, testReports)
            reportsExpectations.first.fulfill()
            reportsExpectations.second.fulfill()
        }

        retrievedRunningEntry.producer.skipNil().startWithValues {
            XCTAssertEqual($0.id, testRunningEntry.id)
            runningEntryExpectations.first.fulfill()
            runningEntryExpectations.second.fulfill()
        }

        feedAPICredentialIntoDataRetriever()
        feedTwoPartPeriodIntoDataRetriever()

        wait(for: [profileExpectations.first, projectsExpectations.first, reportsExpectations.first], timeout: timeoutForExpectations)

        dataRetriever.refreshAllData <~ SignalProducer(value: ())

        wait(for: [profileExpectations.second, projectsExpectations.second, reportsExpectations.second], timeout: timeoutForExpectations)
        XCTAssertNil(lastError.value)
    }


    // MARK: - Test error propagation

    func testErrorWhenRetrievingProfileIsMadeAvailable() {
        retrieveProfileNetworkAction = RetrieveProfileNetworkAction { _ in
            SignalProducer(error: APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError))
        }

        testError(satisfies: { XCTAssertTrue(equalsTestError($0)) } ) { [unowned self] in
            self.feedAPICredentialIntoDataRetriever()
        }
    }

    func testErrorWhenRetrievingProjectsIsMadeAvailable() {
        retrieveProjectsNetworkAction = RetrieveProjectsNetworkAction { _ in
            SignalProducer(error: APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError))
        }

        testError(satisfies: { XCTAssertTrue(equalsTestError($0)) } ) { [unowned self] in
            self.feedAPICredentialIntoDataRetriever()
        }
    }

    func testErrorWhenRetrievingReportsIsMadeAvailable() {
        retrieveReportsNetworkAction = RetrieveReportsNetworkAction { _ in
            SignalProducer(error: APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError))
        }

        testError(satisfies: { XCTAssertTrue(equalsTestError($0)) } ) { [unowned self] in
            self.feedAPICredentialIntoDataRetriever()
            self.feedTwoPartPeriodIntoDataRetriever()
        }
    }

    func testErrorWhenRetrievingRunningEntryIsMadeAvailable() {
        retrieveRunningEntryAction = RetrieveRunningEntryNetworkAction { _ in
            SignalProducer(error: APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError))
        }

        testError(satisfies: { XCTAssertTrue(equalsTestError($0)) } ) { [unowned self] in
            self.dataRetriever.updateRunningEntry <~ SignalProducer(value: ())
        }
    }

    private func testError(satisfies test: @escaping (APIAccessError) -> (), after trigger: () -> ()) {
        makeDataRetriever()
        XCTAssertNil(lastError.value)
        let errorExpectation = expectation(description: "Expecting error value.")
        lastError.producer.skipNil().startWithValues {
            test($0)
            errorExpectation.fulfill()
        }

        trigger()

        wait(for: [errorExpectation], timeout: timeoutForExpectations)
    }


    // MARK: - Test currently running activity

    func testCurrentlyRunningActivity() {
        let profilePipe = Signal<Profile, APIAccessError>.pipe()
        let projectsPipe = Signal<IndexedProjects, APIAccessError>.pipe()
        let reportsPipe = Signal<IndexedTwoPartTimeReports, APIAccessError>.pipe()
        let runningEntryPipe = Signal<RunningEntry?, APIAccessError>.pipe()

        retrieveProfileNetworkAction = RetrieveProfileNetworkAction { _ in
            profilePipe.output.producer
        }

        retrieveProjectsNetworkAction = RetrieveProjectsNetworkAction { _ in
            projectsPipe.output.producer
        }

        retrieveReportsNetworkAction = RetrieveReportsNetworkAction { _ in
            reportsPipe.output.producer
        }

        retrieveRunningEntryAction = RetrieveRunningEntryNetworkAction { _ in
            runningEntryPipe.output.producer
        }

        makeDataRetriever()

        let profileActionExecutionStartedExpectation = expectation(description: "retrieveProfileNetworkAction action execution started")
        let projectsActionExecutionStartedExpectation = expectation(description: "retrieveProjectsNetworkAction action execution started")
        let reportsActionExecutionStartedExpectation = expectation(description: "retrieveReportsNetworkAction action execution started")
        let runningEntryActionExecutionStartedExpectation = expectation(description: "retrieveRunningEntryAction action execution started")

        let profileActionExecutionEndedExpectation = expectation(description: "retrieveProfileNetworkAction action execution ended")
        let projectsActionExecutionEndedExpectation = expectation(description: "retrieveProjectsNetworkAction action execution ended")
        let reportsActionExecutionEndedExpectation = expectation(description: "retrieveReportsNetworkAction action execution ended")
        let runningEntryActionExecutionEndedExpectation = expectation(description: "retrieveRunningEntryAction action execution ended")

        func setUpExpectationFulfillment<T, U>(for action: Action<T, U, APIAccessError>,
                                         start: XCTestExpectation, end: XCTestExpectation) {
            let executionStartedProducer = action.isExecuting.producer.filter { $0 }.map { _ in () }
            executionStartedProducer.startWithValues { start.fulfill() }
            let executionEndedProvider = action.isExecuting.producer.filter { !$0 }.map { _ in () }
            executionEndedProvider.skip(until: executionStartedProducer).startWithValues { end.fulfill() }
        }

        setUpExpectationFulfillment(for: retrieveProfileNetworkAction, start: profileActionExecutionStartedExpectation, end: profileActionExecutionEndedExpectation)
        setUpExpectationFulfillment(for: retrieveProjectsNetworkAction, start: projectsActionExecutionStartedExpectation, end: projectsActionExecutionEndedExpectation)
        setUpExpectationFulfillment(for: retrieveReportsNetworkAction, start: reportsActionExecutionStartedExpectation, end: reportsActionExecutionEndedExpectation)
        setUpExpectationFulfillment(for: retrieveRunningEntryAction, start: runningEntryActionExecutionStartedExpectation, end: runningEntryActionExecutionEndedExpectation)

        let profileActivityStatus = Property(initial: nil, then: lastActivity.producer.filter { $0?.activity == .syncProfile })
        let projectsActivityStatus = Property(initial: nil, then: lastActivity.producer.filter { $0?.activity == .syncProjects })
        let reportsActivityStatus = Property(initial: nil, then: lastActivity.producer.filter { $0?.activity == .syncReports })
        let runningEntryActivityStatus = Property(initial: nil, then: lastActivity.producer.filter { $0?.activity == .syncRunningEntry })

        XCTAssertNil(lastActivity.value)
        XCTAssertNil(profileActivityStatus.value)
        XCTAssertNil(projectsActivityStatus.value)
        XCTAssertNil(reportsActivityStatus.value)
        XCTAssertNil(runningEntryActivityStatus.value)

        feedTwoPartPeriodIntoDataRetriever()


        // First stage: feed API credentials, retrieve profile and running entry

        feedAPICredentialIntoDataRetriever()
        wait(for: [profileActionExecutionStartedExpectation], timeout: timeoutForExpectations)
        wait(for: [runningEntryActionExecutionStartedExpectation], timeout: timeoutForExpectations)

        XCTAssertNotNil(profileActivityStatus.value)
        XCTAssertEqual(profileActivityStatus.value?.isExecuting, true)
        XCTAssertNotNil(runningEntryActivityStatus.value)
        XCTAssertEqual(runningEntryActivityStatus.value?.isExecuting, true)
        XCTAssertNil(projectsActivityStatus.value)
        XCTAssertNil(reportsActivityStatus.value)


        // Second stage: profile retrieved, retrieve projects and reports

        profilePipe.input.send(value: testProfile)
        profilePipe.input.sendCompleted()
        wait(for: [profileActionExecutionEndedExpectation, projectsActionExecutionStartedExpectation, reportsActionExecutionStartedExpectation], timeout: timeoutForExpectations)

        XCTAssertEqual(profileActivityStatus.value?.isSuccessful, true) // profile value fed means profile retrieval successful
        XCTAssertEqual(runningEntryActivityStatus.value?.isExecuting, true) // no running entry value fed means still executing
        XCTAssertNotNil(projectsActivityStatus.value)
        XCTAssertEqual(projectsActivityStatus.value?.isExecuting, true)
        XCTAssertNotNil(reportsActivityStatus.value)
        XCTAssertEqual(reportsActivityStatus.value?.isExecuting, true)


        // Feed running entry at this point and assess activity is successfully completed

        runningEntryPipe.input.send(value: testRunningEntry)
        runningEntryPipe.input.sendCompleted()
        wait(for: [runningEntryActionExecutionEndedExpectation], timeout: timeoutForExpectations)
        XCTAssertEqual(runningEntryActivityStatus.value?.isSuccessful, true)

        
        // Third stage: project and reports retrieved

        projectsPipe.input.send(value: testProjects)
        projectsPipe.input.sendCompleted()
        reportsPipe.input.send(value: testReports)
        reportsPipe.input.sendCompleted()

        wait(for: [projectsActionExecutionEndedExpectation, reportsActionExecutionEndedExpectation], timeout: timeoutForExpectations)
        XCTAssertNotNil(projectsActivityStatus.value)
        XCTAssertEqual(projectsActivityStatus.value?.isSuccessful, true)
        XCTAssertNotNil(reportsActivityStatus.value)
        XCTAssertEqual(reportsActivityStatus.value?.isSuccessful, true)
    }


    // MARK: - Test cache

    func testProfileIsRetrievedFromCache() {
        retrieveProfileNetworkAction = RetrieveProfileNetworkAction { _ in
            return SignalProducer.empty
        }

        retrieveProfileCacheAction = RetrieveProfileCacheAction { _ in
            let scheduler = QueueScheduler()
            let pipe = Signal<Profile, NoError>.pipe()
            scheduler.schedule(after: Date().addingTimeInterval(0.250)) {
                pipe.input.send(value: testProfile)
            }
            return pipe.output.producer.map { Optional($0) }
        }

        testRetrieval(of: retrievedProfile, satisfying: { XCTAssertEqual($0, testProfile) }, after: { })
    }

    func testProfileFromNetworkIsStoredInCache() {
        let cacheStoreExpectation = expectation(description: "Expecting incoming Profile value to be stored in cache.")

        storeProfileCacheAction = StoreProfileCacheAction {
            XCTAssertEqual($0, testProfile)
            cacheStoreExpectation.fulfill()
            return SignalProducer.empty
        }

        makeDataRetriever()

        // trigger retrieval of profile from the "network"
        feedAPICredentialIntoDataRetriever()

        wait(for: [cacheStoreExpectation], timeout: timeoutForExpectations)
    }
}
