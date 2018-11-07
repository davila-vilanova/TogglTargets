//
//  TogglAPIDataRetrieverTest.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 20.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest
import Result
import ReactiveSwift

private let dummyAPIToken = "8a7f2049ed"
private let testCredential = TogglAPITokenCredential(apiToken: dummyAPIToken)!
private let testReportPeriod = Period(start: DayComponents(year: 2017, month: 12, day: 1),
                                      end: DayComponents(year: 2017, month: 12, day: 31))
private let firstDayOfPeriod = DayComponents(year: 2017, month: 12, day: 1)
private let yesterday = DayComponents(year: 2017, month: 12, day: 14)
private let today = DayComponents(year: 2017, month: 12, day: 15)
private let twoPartReportPeriods =
    TwoPartTimeReportPeriod(scope: testReportPeriod,
                            previousToDayOfRequest: Period(start: firstDayOfPeriod, end: yesterday),
                            dayOfRequest: today)

private let testProfile = Profile(id: 118030,
                                      name: "Ardilla Squirrel",
                                      email: "whatup@ardillita.me",
                                      imageUrl: nil,
                                      timezone: "Europe/Berlin",
                                      workspaces: [Workspace(id: 1, name: "A"),
                                                   Workspace(id: 2, name: "B")],
                                      apiToken: dummyAPIToken)

private let testProjects: IndexedProjects = [100: Project(id: 100, name: "first", active: true, workspaceId: 1),
                                                 200: Project(id: 200, name: "second", active: true, workspaceId: 1),
                                                 300: Project(id: 300, name: "third", active: true, workspaceId: 2)]

private let testReports: IndexedTwoPartTimeReports =
    [ 100: TwoPartTimeReport(projectId: 100,
                             period: testReportPeriod,
                             workedTimeUntilDayBeforeRequest: 7200,
                             workedTimeOnDayOfRequest: 2100),
      200: TwoPartTimeReport(projectId: 200,
                             period: testReportPeriod,
                             workedTimeUntilDayBeforeRequest: 3812,
                             workedTimeOnDayOfRequest: 0),
      300: TwoPartTimeReport(projectId: 300,
                             period: testReportPeriod,
                             workedTimeUntilDayBeforeRequest: 0,
                             workedTimeOnDayOfRequest: 1800) ]

private let testRunningEntry: RunningEntry = {
    let todayDate = Calendar.iso8601.date(from: today)!
    let hour: TimeInterval = 3600
    return RunningEntry(id: 8110, projectId: 200, start: todayDate + (8 * hour), retrieved: todayDate + (9 * hour))
}()

private let testUnderlyingError = NSError(domain: "TogglAPIDataRetrieverTest", code: -4, userInfo: nil)
private let testError = APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError)
private func equalsTestError(_ candidate: APIAccessError) -> Bool {
    switch candidate {
    case .loadingSubsystemError(let underlying):
        let nsError = underlying as NSError
        return nsError.domain == testUnderlyingError.domain
            && nsError.code == testUnderlyingError.code
    default: return false
    }
}

private let timeoutForExpectations = TimeInterval(1.0)

class TogglAPIDataRetrieverTest: XCTestCase { // swiftlint:disable:this type_body_length

    var retrieveProfileNetworkAction: RetrieveProfileNetworkAction!
    var retrieveProfileCacheAction: RetrieveProfileCacheAction!
    var cachedProfile: MutableProperty<Profile?>!
    var retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction!
    var retrieveProjectsCacheAction: RetrieveProjectsCacheAction!
    var cachedProjects: MutableProperty<IndexedProjects?>!
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
        cachedProfile = MutableProperty(nil)

        retrieveProjectsNetworkAction = RetrieveProjectsNetworkAction { workspaceIDs in
            // Return empty projects if the workspace IDs don't match the expected ones
            guard Set<Int64>(workspaceIDs) == Set<Int64>(testProfile.workspaces.map { $0.id }) else {
                return SignalProducer(value: IndexedProjects())
            }
            return SignalProducer(value: testProjects)
        }
        retrieveProjectsCacheAction = RetrieveProjectsCacheAction { _ in SignalProducer(value: nil) }
        cachedProjects = MutableProperty(nil)

        retrieveReportsNetworkAction = RetrieveReportsNetworkAction { (workspaceIDs, _) in
            // Return empty reports if the workspace IDs don't match the expected ones
            guard Set<Int64>(workspaceIDs) == Set<Int64>(testProfile.workspaces.map { $0.id }) else {
                return SignalProducer(value: IndexedTwoPartTimeReports())
            }
            return SignalProducer(value: testReports)
        }

        retrieveRunningEntryAction = RetrieveRunningEntryNetworkAction { _ in SignalProducer(value: testRunningEntry) }
    }

    override func tearDown() {
        retrieveProfileNetworkAction = nil
        retrieveProfileCacheAction = nil
        cachedProfile = nil
        retrieveProjectsNetworkAction = nil
        retrieveProjectsCacheAction = nil
        cachedProjects = nil
        retrieveReportsNetworkAction = nil
        retrieveRunningEntryAction = nil

        dataRetriever = nil

        retrievedProfile = nil
        retrievedProjects = nil
        retrievedReports = nil
        retrievedRunningEntry = nil
        lastActivity = nil
        lastError = nil

        super.tearDown()
    }

    private func makeDataRetriever() {
        dataRetriever = CachedTogglAPIDataRetriever(
            retrieveProfileNetworkActionMaker: { [action = retrieveProfileNetworkAction!] in action },
            retrieveProfileFromCache: retrieveProfileCacheAction,
            storeProfileInCache: cachedProfile.bindingTarget,
            retrieveProjectsNetworkActionMaker: { [action = retrieveProjectsNetworkAction!] _ in action },
            retrieveProjectsFromCache: retrieveProjectsCacheAction,
            storeProjectsInCache: cachedProjects.bindingTarget,
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
        testRetrieval(of: retrievedProfile, satisfying: { XCTAssertEqual($0, testProfile) },
                      after: feedAPICredentialIntoDataRetriever)
    }

    func testRunningEntryIsRetrievedWhenAPICredentialBecomesAvailable() {
        testRetrieval(of: retrievedRunningEntry, satisfying: { XCTAssertEqual($0, testRunningEntry) },
                      after: feedAPICredentialIntoDataRetriever)
    }

    func testProjectsAreRetrievedWhenWorkspaceIDsBecomeAvailable() {
        testRetrieval(of: retrievedProjects, satisfying: { XCTAssertEqual($0, testProjects) },
                      after: feedAPICredentialIntoDataRetriever)
    }

    func testReportsAreRetrievedWhenWorkspaceIDsAndPeriodsBecomeAvailable() {
        testRetrieval(of: retrievedReports,
                      satisfying: { XCTAssertEqual($0, testReports) },
                      after: { [unowned self] in
                        self.feedAPICredentialIntoDataRetriever()
                        self.feedTwoPartPeriodIntoDataRetriever()
        })
    }

    func testRetrieveRunningEntryOnDemand() {
        makeDataRetriever()

        XCTAssertNil(retrievedRunningEntry.value)
        XCTAssertNil(lastError.value)
        let automaticRetrievalExpectation =
            expectation(description: "Expecting automatically retrieved value for running entry")

        retrievedRunningEntry.producer.skip(first: 1).take(first: 1).startWithValues {
            XCTAssertNotNil($0)
            automaticRetrievalExpectation.fulfill()
        }

        feedAPICredentialIntoDataRetriever()
        wait(for: [automaticRetrievalExpectation], timeout: timeoutForExpectations)

        let onDemandRetrievalExpectation =
            expectation(description: "Expecting on demand retrieved value for running entry")

        retrievedRunningEntry.producer.skip(first: 1).take(first: 1).startWithValues {
            XCTAssertNotNil($0)
            onDemandRetrievalExpectation.fulfill()
        }
        dataRetriever.updateRunningEntry <~ SignalProducer(value: ())
        wait(for: [onDemandRetrievalExpectation], timeout: timeoutForExpectations)
    }

    private func testRetrieval<T>(of propertyProvider: @autoclosure () -> Property<T?>,
                                  satisfying test: @escaping (T) -> Void, after trigger: () -> Void) {
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

    func testRefreshAllData() { // swiftlint:disable:this function_body_length
        makeDataRetriever()
        XCTAssertNil(retrievedProfile.value)
        XCTAssertNil(retrievedProjects.value)
        XCTAssertNil(retrievedReports.value)
        XCTAssertNil(retrievedRunningEntry.value)
        XCTAssertNil(lastError.value)

        func retrieveTwiceExpectations(for entityName: String)
            -> (first: XCTestExpectation, second: XCTestExpectation) {
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

        wait(for: [profileExpectations.first, projectsExpectations.first, reportsExpectations.first],
             timeout: timeoutForExpectations)

        dataRetriever.refreshAllData <~ SignalProducer(value: ())

        wait(for: [profileExpectations.second, projectsExpectations.second, reportsExpectations.second],
             timeout: timeoutForExpectations)
        XCTAssertNil(lastError.value)
    }

    // MARK: - Test error propagation

    func testErrorWhenRetrievingProfileIsMadeAvailable() {
        retrieveProfileNetworkAction = RetrieveProfileNetworkAction { _ in
            SignalProducer(error: APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError))
        }

        testError(satisfies: { XCTAssertTrue(equalsTestError($0)) },
                  after: { [unowned self] in
                    self.feedAPICredentialIntoDataRetriever()
        })
    }

    func testErrorWhenRetrievingProjectsIsMadeAvailable() {
        retrieveProjectsNetworkAction = RetrieveProjectsNetworkAction { _ in
            SignalProducer(error: APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError))
        }

        testError(satisfies: { XCTAssertTrue(equalsTestError($0)) },
                  after: { [unowned self] in
                    self.feedAPICredentialIntoDataRetriever()
        })
    }

    func testErrorWhenRetrievingReportsIsMadeAvailable() {
        retrieveReportsNetworkAction = RetrieveReportsNetworkAction { _ in
            SignalProducer(error: APIAccessError.loadingSubsystemError(underlyingError: testUnderlyingError))
        }

        testError(satisfies: { XCTAssertTrue(equalsTestError($0)) },
                  after: { [unowned self] in
                    self.feedAPICredentialIntoDataRetriever()
                    self.feedTwoPartPeriodIntoDataRetriever()
        })
    }

    private func testError(satisfies test: @escaping (APIAccessError) -> Void, after trigger: () -> Void) {
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

    func testCurrentlyRunningActivity() { // swiftlint:disable:this function_body_length
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

        let profileActionExecutionStartedExpectation =
            expectation(description: "retrieveProfileNetworkAction action execution started")
        let projectsActionExecutionStartedExpectation = // swiftlint:disable:this identifier_name
            expectation(description: "retrieveProjectsNetworkAction action execution started")
        let reportsActionExecutionStartedExpectation =
            expectation(description: "retrieveReportsNetworkAction action execution started")
        let runningEntryActionExecutionStartedExpectation = // swiftlint:disable:this identifier_name
            expectation(description: "retrieveRunningEntryAction action execution started")

        let profileActionExecutionEndedExpectation =
            expectation(description: "retrieveProfileNetworkAction action execution ended")
        let projectsActionExecutionEndedExpectation =
            expectation(description: "retrieveProjectsNetworkAction action execution ended")
        let reportsActionExecutionEndedExpectation =
            expectation(description: "retrieveReportsNetworkAction action execution ended")
        let runningEntryActionExecutionEndedExpectation = // swiftlint:disable:this identifier_name
            expectation(description: "retrieveRunningEntryAction action execution ended")

        let (lifetime, token) = Lifetime.make()

        func setUpExpectationFulfillment<T, U>(for action: Action<T, U, APIAccessError>,
                                               start: XCTestExpectation, end: XCTestExpectation) {
            let executionStartedProducer = action.isExecuting.producer.filter { $0 }.map { _ in () }
            lifetime += executionStartedProducer.startWithValues { start.fulfill() }
            let executionEndedProvider = action.isExecuting.producer.filter { !$0 }.map { _ in () }
            lifetime += executionEndedProvider.skip(until: executionStartedProducer).startWithValues { end.fulfill() }
        }

        setUpExpectationFulfillment(for: retrieveProfileNetworkAction,
                                    start: profileActionExecutionStartedExpectation,
                                    end: profileActionExecutionEndedExpectation)
        setUpExpectationFulfillment(for: retrieveProjectsNetworkAction,
                                    start: projectsActionExecutionStartedExpectation,
                                    end: projectsActionExecutionEndedExpectation)
        setUpExpectationFulfillment(for: retrieveReportsNetworkAction,
                                    start: reportsActionExecutionStartedExpectation,
                                    end: reportsActionExecutionEndedExpectation)
        setUpExpectationFulfillment(for: retrieveRunningEntryAction,
                                    start: runningEntryActionExecutionStartedExpectation,
                                    end: runningEntryActionExecutionEndedExpectation)

        let profileActivityStatus =
            Property(initial: nil, then: lastActivity.producer.filter { $0?.activity == .syncProfile })
        let projectsActivityStatus =
            Property(initial: nil, then: lastActivity.producer.filter { $0?.activity == .syncProjects })
        let reportsActivityStatus =
            Property(initial: nil, then: lastActivity.producer.filter { $0?.activity == .syncReports })
        let runningEntryActivityStatus =
            Property(initial: nil, then: lastActivity.producer.filter { $0?.activity == .syncRunningEntry })

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
        wait(for: [profileActionExecutionEndedExpectation,
                   projectsActionExecutionStartedExpectation,
                   reportsActionExecutionStartedExpectation],
             timeout: timeoutForExpectations)

         // profile value fed means profile retrieval successful
        XCTAssertEqual(profileActivityStatus.value?.isSuccessful, true)

         // no running entry value fed means still executing
        XCTAssertEqual(runningEntryActivityStatus.value?.isExecuting, true)

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

        wait(for: [projectsActionExecutionEndedExpectation, reportsActionExecutionEndedExpectation],
             timeout: timeoutForExpectations)
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
        cachedProfile.producer.skipNil().startWithValues {
            XCTAssertEqual($0, testProfile)
            cacheStoreExpectation.fulfill()
        }

        makeDataRetriever()

        // trigger retrieval of profile from the "network"
        feedAPICredentialIntoDataRetriever()

        wait(for: [cacheStoreExpectation], timeout: timeoutForExpectations)
    }
} // swiftlint:disable:this file_length
