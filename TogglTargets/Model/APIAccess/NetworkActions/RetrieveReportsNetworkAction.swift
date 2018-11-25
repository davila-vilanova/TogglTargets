//
//  RetrieveReportsNetworkAction.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
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

import Foundation
import ReactiveSwift

/// Action that takes an array of `WorkspaceID` values and a two-part period, retrieves from the Toggl API the
/// corresponding time reports and merges them in an `IndexedTwoPartTimeReports` dictionary.
typealias RetrieveReportsNetworkAction =
    Action<([WorkspaceID], TwoPartTimeReportPeriod), IndexedTwoPartTimeReports, APIAccessError>

/// A function or closure that takes a `Property` that holds and tracks changes to a `URLSession` optional value and
/// generates a `RetrieveReportsNetworkAction` that is enabled whenever the the provided `Property` holds a non-`nil`
/// value.
///
/// This can be used to inject a `RetrieveReportsNetworkAction` into an entity that needs to make the `Action` depend
/// on the state of its `URLSession`.
typealias RetrieveReportsNetworkActionMaker = (Property<URLSession?>) -> RetrieveReportsNetworkAction

/// A concrete, non-mock implementation of `RetrieveReportsNetworkActionMaker`.
func makeRetrieveReportsNetworkAction(_ urlSession: Property<URLSession?>) -> RetrieveReportsNetworkAction {
    let networkRetriever = { (endpoint: String, session: URLSession) in
        session.togglAPIRequestProducer(for: endpoint, decoder: ReportsService.decodeReportEntries)
    }
    return makeRetrieveReportsNetworkAction(urlSession, networkRetriever)
}

/// Takes a property holding an optional `URLSession` and a `TogglAPINetworkRetriever` that retrieves one array of
/// `ReportEntry` values for one endpoint, and returns a `RetrieveProjectsNetworkAction` that applies request splitting
/// and reports combining and indexing logic on top of them.
///
/// - parameters:
///   - urlSession: A `Property` that holds and tracks changes to a `URLSession` optional value and is used as the
///                 state of the returned `Action`.
///   - networkRetriever: A `TogglAPINetworkRetriever` that retrieves an array of `ReportEntry` values from an input
///                       Toggl API endpoint.
///
/// - returns: A `RetrieveReportsNetworkAction` that applies request splitting, projects combining and indexing logic
///            on top of the provided `URLSession` and `TogglAPINetworkRetriever`.
func makeRetrieveReportsNetworkAction(_ urlSession: Property<URLSession?>,
                                      _ networkRetriever:
    @escaping TogglAPINetworkRetriever<[ReportEntry]>) -> RetrieveReportsNetworkAction {

    return RetrieveReportsNetworkAction(unwrapping: urlSession) { (session, inputs) in
        let (workspaceIDs, period) = inputs
        let reportEntriesRetriever = { (endpoint: String) in networkRetriever(endpoint, session) }
        let workedUntilYesterday = workedTimesProducer(workspaceIDs: workspaceIDs,
                                                       period: period.previousToDayOfRequest,
                                                       reportEntriesRetriever: reportEntriesRetriever)
        let workedToday = workedTimesProducer(workspaceIDs: workspaceIDs,
                                              period: period.forDayOfRequest,
                                              reportEntriesRetriever: reportEntriesRetriever)
        return SignalProducer.combineLatest(workedUntilYesterday,
                                            workedToday,
                                            SignalProducer(value: period.scope))
            .map(generateIndexedReportsFromWorkedTimes)
    }
}

private let userAgent = "david@davi.la"

private typealias IndexedWorkedTimes = [ProjectID: WorkedTime]

/// Returns a SignalProducer that upon start retrieves, using the closure passed as reportEntriesRetriever, the amounts
/// of time worked for each of the projects in the provided workspace IDs during a the time period delimited by the
/// provided `Period`.
///
/// - parameters:
///   - workspaceIDs: the IDs of the workspaces for which to retrieve the worked times.
///   - period: the `Period` representing the start and end dates delimiting the time period for which to request
///     the worked time reports. Nil periods may be passed and they will cause the returning producer to emit a single
///     empty `IndexedWorkedTimes` value.
///   - reportEntriesRetriever a closure which given an endpoint corresponding to the Toggl's reports API and query 
///     for a given workspace and period will return a `SignalProducer` of `ReportEntry`es corresponding to that
///     workspace and period. If the returned producer fails, its failure will be immediately propagated.
///
/// - returns: A producer that will emit a single value containing the aggregated `IndexedWorkedTimes` of all
///            workspaces.
private func workedTimesProducer(workspaceIDs: [WorkspaceID],
                                 period: Period?,
                                 reportEntriesRetriever:
                                    @escaping (String) -> SignalProducer<[ReportEntry], APIAccessError>)
    ->  SignalProducer<IndexedWorkedTimes, APIAccessError> {
        guard let period = period else {
            return SignalProducer(value: IndexedWorkedTimes()) // empty
        }

        func timesProducer(forSingle workspaceID: WorkspaceID) -> SignalProducer<IndexedWorkedTimes, APIAccessError> {
            let endpoint =
                ReportsService.endpoint(workspaceId: workspaceID,
                                        since: period.start.iso8601String, until: period.end.iso8601String,
                                        userAgent: userAgent)
            return reportEntriesRetriever(endpoint)
                .reduce(into: IndexedWorkedTimes()) { (indexedWorkedTimeEntries, reportEntries) in
                    for entry in reportEntries {
                        indexedWorkedTimeEntries[entry.id] = WorkedTime.from(milliseconds: entry.time)
                    }
            }
        }

        return SignalProducer(workspaceIDs)
            .map(timesProducer)
            .flatten(.concat)
            .reduce(IndexedWorkedTimes(), { (combined: IndexedWorkedTimes, thisWorkspace: IndexedWorkedTimes)
                -> IndexedWorkedTimes in
                // Not expecting duplicates
                combined.merging(thisWorkspace,
                                 uniquingKeysWith: { valueInCombinedTimes, _ in valueInCombinedTimes })
            })
}

/// Returns a producer that, on success, emits a single IndexedWorkedTimes value corresponding to the aggregate of
/// all the provided workspace IDs, then completes.
private func generateIndexedReportsFromWorkedTimes(untilYesterday: IndexedWorkedTimes,
                                                   today: IndexedWorkedTimes,
                                                   fullPeriod: Period)
    -> [ProjectID: TwoPartTimeReport] {
        var reports = [ProjectID: TwoPartTimeReport]()
        let ids: Set<ProjectID> = Set<ProjectID>(untilYesterday.keys).union(today.keys)
        for projectId in ids {
            let timeWorkedPreviousToToday: TimeInterval = untilYesterday[projectId] ?? 0.0
            let timeWorkedToday: TimeInterval = today[projectId] ?? 0.0
            reports[projectId] = TwoPartTimeReport(projectId: projectId,
                                            period: fullPeriod,
                                            workedTimeUntilDayBeforeRequest: timeWorkedPreviousToToday,
                                            workedTimeOnDayOfRequest: timeWorkedToday)
        }
        return reports
}

/// Represents the data returned in the body of the response obtained by calling Toggl's reports summary endpoint
/// with a valid credential.
private struct ReportsService: Decodable {
    static func endpoint(workspaceId: WorkspaceID, since: String, until: String, userAgent: String) -> String {
        return "/reports/api/v2/summary?workspace_id=\(workspaceId)&since=\(since)" +
        "&until=\(until)&grouping=projects&subgrouping=users&user_agent=\(userAgent)"
    }

    let reportEntries: [ReportEntry]

    private enum CodingKeys: String, CodingKey {
        case reportEntries = "data"
    }

    static func decodeReportEntries(data: Data, response: URLResponse) throws -> [ReportEntry] {
        return try JSONDecoder().decode(ReportsService.self, from: data).reportEntries
    }
}

private extension ReportsService {
    static func endpoint(with userAgent: String) -> (WorkspaceID, DayComponents, DayComponents) -> String {
        return { (workspaceId, since, until) in
            ReportsService.endpoint(workspaceId: workspaceId,
                                    since: since.iso8601String,
                                    until: until.iso8601String,
                                    userAgent: userAgent)
        }
    }
}
