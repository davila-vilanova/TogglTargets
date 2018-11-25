//
//  MakeRetrieveReportsNetworkActionTest.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 24.12.17.
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

private typealias ReportEntriesFixture = [WorkspaceID: [EndDay: [ReportEntry]]]

private let timeoutForExpectations = TimeInterval(1.0)

class MakeRetrieveReportsNetworkActionTest: XCTestCase {

    private let reportEntriesFixture = makeReportEntriesFixture()

    private var networkRetriever: TogglAPINetworkRetriever<[ReportEntry]>!

    private var indexedNetworkRetrieverExpectations = [WorkspaceID: [EndDay: XCTestExpectation]]()
    private var networkRetrieverExpectations: [XCTestExpectation] {
        var collectedExpectations = [XCTestExpectation]()
        for (_, expectationsByEndDate) in indexedNetworkRetrieverExpectations {
            collectedExpectations.append(contentsOf: expectationsByEndDate.map { $1 })
        }
        return collectedExpectations
    }

    private var retrieveReportsNetworkAction: RetrieveReportsNetworkAction!

    // The exact URLSession value does not matter for the scope of this test case,
    // only whether it's a nil value or some URLSession value.
    private let urlSession = MutableProperty<URLSession?>(URLSession.shared)

    override func setUp() {
        super.setUp()

        for wid in workspaceIDs {
            var expectationsByEndDate = [EndDay: XCTestExpectation]()
            for endDate in EndDay.allCases {
                expectationsByEndDate[endDate] = expectation(description:
                    "networkRetriever invocation expectation for workspace ID: \(wid), endDate: \(endDate)")
            }
            indexedNetworkRetrieverExpectations[wid] = expectationsByEndDate
        }

        networkRetriever = { [reportEntriesFixture, expectations = indexedNetworkRetrieverExpectations] (endpoint, _) in
            guard let wid = endpoint.containedWorkspaceID() else {
                XCTFail("Endpoint does not include any of the workspace IDs in the fixture.")
                fatalError()
            }
            guard let endDate = endpoint.containedEndDate() else {
                XCTFail("Endpoint does not include any of the end dates in the fixture.")
                fatalError()
            }
            guard let reportEntries = reportEntriesFixture[wid]?[endDate] else {
                XCTFail("Report entries not present for workspace ID \(wid), endDate: \(endDate)")
                fatalError()
            }
            guard let expectation = expectations[wid]?[endDate] else {
                XCTFail("Expectation not present for workspace ID \(wid), endDate: \(endDate)")
                fatalError()
            }
            expectation.fulfill()
            return SignalProducer(value: reportEntries)
        }

        let actionState = Property(initial: nil, then: urlSession.producer)
        retrieveReportsNetworkAction = makeRetrieveReportsNetworkAction(actionState, networkRetriever)
    }

    override func tearDown() {
        indexedNetworkRetrieverExpectations = [WorkspaceID: [EndDay: XCTestExpectation]]()
        networkRetriever = nil
        super.tearDown()
    }

    func testNetworkRetrieverIsInvokedForAllWorkspaceIDEndDateCombinations() {
        retrieveReportsNetworkAction.apply((workspaceIDs, twoPartTimePeriod)).start()
        wait(for: networkRetrieverExpectations, timeout: timeoutForExpectations)
    }

    func testReportsFromAllWorkspacesAndPeriodsAreCombinedInTwoPartTimeReportsAndIndexed() {
        var reportEntriesByProjectID = [ProjectID: [EndDay: [ReportEntry]]]()

        let valueExpectation = expectation(description: "retrieveReportsNetworkAction value emitted")

        retrieveReportsNetworkAction.values.producer.startWithValues { [reportEntriesFixture] (indexedOutputReports) in
            defer {
                valueExpectation.fulfill()
            }

            let projectIDs: [ProjectID] = [13, 28, 34, 49]
            XCTAssertEqual(indexedOutputReports.count, projectIDs.count)

            for projectID in projectIDs {
                guard let twoPartReport = indexedOutputReports[projectID] else {
                    XCTFail("No corresponding output project found for project ID: \(projectID)")
                    break
                }
                XCTAssertEqual(twoPartReport.projectId, projectID, "Output projects must be indexed by project ID")
                XCTAssertEqual(twoPartReport.period,
                               fullReportPeriod,
                               "Output projects period must be the full report period")
            }

            XCTAssertEqual(indexedOutputReports[13]!.workedTimeUntilDayBeforeRequest, 84600)
            XCTAssertEqual(indexedOutputReports[13]!.workedTimeOnDayOfRequest, 1300)

            XCTAssertEqual(indexedOutputReports[28]!.workedTimeUntilDayBeforeRequest, 20046)
            XCTAssertEqual(indexedOutputReports[28]!.workedTimeOnDayOfRequest, 3245)

            XCTAssertEqual(indexedOutputReports[34]!.workedTimeUntilDayBeforeRequest, 173335)
            XCTAssertEqual(indexedOutputReports[34]!.workedTimeOnDayOfRequest, 9900)

            XCTAssertEqual(indexedOutputReports[49]!.workedTimeUntilDayBeforeRequest, 123228)
            XCTAssertEqual(indexedOutputReports[49]!.workedTimeOnDayOfRequest, 1428)
        }

        retrieveReportsNetworkAction.apply((workspaceIDs, twoPartTimePeriod)).start()
        wait(for: networkRetrieverExpectations + [valueExpectation], timeout: timeoutForExpectations)
    }
}

private let workspaceIDs: [WorkspaceID] = [823, 172]

private let startDay = DayComponents(year: 2017, month: 12, day: 1)
private let endDay = DayComponents(year: 2017, month: 12, day: 31)
private let yesterdayComps = DayComponents(year: 2017, month: 12, day: 23)
private let todayComps = DayComponents(year: 2017, month: 12, day: 24)

private let fullReportPeriod = Period(start: startDay, end: endDay)
private let twoPartTimePeriod =
    TwoPartTimeReportPeriod(scope: fullReportPeriod,
                            previousToDayOfRequest: Period(start: startDay, end: yesterdayComps),
                            dayOfRequest: todayComps)

private enum EndDay {
    case yesterday
    case today

    static let allCases: [EndDay] = [.yesterday, .today]
    static func fromISO8601String(_ string: String) -> EndDay? {
        if string == yesterdayComps.iso8601String {
            return .yesterday
        } else if string == todayComps.iso8601String {
            return .today
        } else {
            return nil
        }
    }

    var iso8601String: String {
        switch self {
        case .yesterday:
            return yesterdayComps.iso8601String
        case .today:
            return todayComps.iso8601String
        }
    }
}

fileprivate extension String {
    func containedWorkspaceID() -> WorkspaceID? {
        for wid in workspaceIDs {
            if self.contains(String(describing: wid)) {
                return wid
            }
        }
        return nil
    }

    func containedEndDate() -> EndDay? {
        for day in EndDay.allCases {
            if self.contains("until=\(day.iso8601String)") {
                return day
            }
        }
        return nil
    }
}

private let jsonStringWid823UntilYesterday = """
[
{
"id": 13,
"time": 84600000
},
{
"id": 28,
"time": 20046000
}
]
"""

private let jsonStringWid823Today = """
[
{
"id": 13,
"time": 1300000
},
{
"id": 28,
"time": 3245000
}
]
"""

private let jsonStringWid172UntilYesterday = """
[
{
"id": 34,
"time": 173335000
},
{
"id": 49,
"time": 123228000
}
]
"""

private let jsonStringWid172Today = """
[
{
"id": 34,
"time": 9900000
},
{
"id": 49,
"time": 1428000
}
]
"""

private func makeReportEntriesFixture() -> ReportEntriesFixture {
    let mappedJSONStrings: [WorkspaceID: [EndDay: String]] =
        [823: [.yesterday: jsonStringWid823UntilYesterday,
                .today: jsonStringWid823Today],
         172: [.yesterday: jsonStringWid172UntilYesterday,
                .today: jsonStringWid172Today]]

    var reportEntriesByWorkspaceIDEndDay = ReportEntriesFixture()
    let decoder = JSONDecoder()
    for wid in workspaceIDs {
        var entriesForWorkspace = [EndDay: [ReportEntry]]()
        for endDate in EndDay.allCases {
            guard let jsonString = mappedJSONStrings[wid]?[endDate],
                let jsonData = jsonString.data(using: .utf8),
                let reportEntries = try? decoder.decode([ReportEntry].self, from: jsonData) else {
                    XCTFail("Fixture data is not properly set up.")
                    fatalError()
            }
            entriesForWorkspace[endDate] = reportEntries
        }
        reportEntriesByWorkspaceIDEndDay[wid] = entriesForWorkspace
    }

    return reportEntriesByWorkspaceIDEndDay
}
