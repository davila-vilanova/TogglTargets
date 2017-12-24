//
//  RetrieveReportsNetworkAction.swift
//  TogglGoals
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

/// A dictionary of `TwoPartTimeReport` values indexed by their corresponding
/// project ID.
typealias IndexedTwoPartTimeReports = [ProjectID : TwoPartTimeReport]

/// Action that takes an array of `WorkspaceID` values and a two-part period,
/// retrieves from the Toggl API the corresponding time reports and merges them
/// in an `IndexedTwoPartTimeReports` dictionary.
typealias RetrieveReportsNetworkAction =
    Action<([WorkspaceID], TwoPartTimeReportPeriod), IndexedTwoPartTimeReports, APIAccessError>


/// A function or closure that takes a `Property` that holds and tracks changes
/// to a `URLSession` optional value and generates a `RetrieveReportsNetworkAction`
/// that is enabled whenever the the provided `Property` holds a non-`nil` value.
///
/// This can be used to inject a `RetrieveReportsNetworkAction` into an entity
/// that needs to make the `Action` depend from the state of its `URLSession`.
typealias RetrieveReportsNetworkActionMaker = (Property<URLSession?>) -> RetrieveReportsNetworkAction

/// A concrete, non-mock implementation of `RetrieveReportsNetworkActionMaker`.
func makeRetrieveReportsNetworkAction(_ urlSession: Property<URLSession?>) -> RetrieveReportsNetworkAction {
    let networkRetriever = { (endpoint: String, session: URLSession) in
        session.togglAPIRequestProducer(for: endpoint, decoder: ReportsService.decodeReportEntries)
    }
    return makeRetrieveReportsNetworkAction(urlSession, networkRetriever)
}

/// Takes a property holding an optional `URLSession` and a `TogglAPINetworkRetriever`
/// that retrieves one array of `ReportEntry` values for one endpoint and a `URLSession`
/// value, and returns a `RetrieveProjectsNetworkAction` that applies request
/// splitting, reports combining and indexing logic on top of them.
///
/// - parameters:
///   - urlSession: A `Property` that holds and tracks changes to a `URLSession`
///                 optional value and is used as the state of the returned `Action`
///   - networkRetriever: A `TogglAPINetworkRetriever` that retrieves an array of
///                       `ReportEntry` values from an input Toggl API endpoint.
///
/// - returns: A `RetrieveReportsNetworkAction` that applies request splitting,
///            projects combining and indexing logic on top of the provided
///            `URLSession` and `TogglAPINetworkRetriever`.

func makeRetrieveReportsNetworkAction(_ urlSession: Property<URLSession?>, _ networkRetriever: @escaping TogglAPINetworkRetriever<[ReportEntry]>) -> RetrieveReportsNetworkAction {

    return RetrieveReportsNetworkAction(unwrapping: urlSession) { (session, inputs) in
        let (workspaceIDs, period) = inputs
        let reportEntriesRetriever = { (endpoint: String) in networkRetriever(endpoint, session) }
        let workedUntilYesterday = workedTimesProducer(workspaceIDs: workspaceIDs, period: period.previousToDayOfRequest, reportEntriesRetriever: reportEntriesRetriever)
        let workedToday = workedTimesProducer(workspaceIDs: workspaceIDs, period: period.forDayOfRequest, reportEntriesRetriever: reportEntriesRetriever)
        return SignalProducer.combineLatest(workedUntilYesterday, workedToday, SignalProducer(value: period.scope))
            .map(generateIndexedReportsFromWorkedTimes)
    }
}

fileprivate let UserAgent = "david@davi.la"

fileprivate typealias IndexedWorkedTimes = [ProjectID : WorkedTime]

fileprivate func workedTimesProducer(workspaceIDs: [WorkspaceID], period: Period?, reportEntriesRetriever: @escaping (String) -> SignalProducer<[ReportEntry], APIAccessError>) -> SignalProducer<IndexedWorkedTimes, APIAccessError> {
        guard let period = period else {
            return SignalProducer(value: IndexedWorkedTimes()) // empty
        }

        func timesProducer(forSingle workspaceID: WorkspaceID) -> SignalProducer<IndexedWorkedTimes, APIAccessError> {
            let endpoint =
                ReportsService.endpoint(workspaceId: workspaceID,
                                        since: period.start.iso8601String, until: period.end.iso8601String,
                                        userAgent: UserAgent)
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
            .reduce(IndexedWorkedTimes(), { (combined: IndexedWorkedTimes, thisWorkspace: IndexedWorkedTimes) -> IndexedWorkedTimes in
                combined.merging(thisWorkspace, uniquingKeysWith: { valueInCombinedTimes, _ in valueInCombinedTimes }) // Not expecting duplicates
            })
}

/// Returns a producer that, on success, emits a single IndexedWorkedTimes value
/// corresponding to the aggregate of all the provided workspace IDs, then completes.
fileprivate func generateIndexedReportsFromWorkedTimes(untilYesterday: IndexedWorkedTimes,
                                           today: IndexedWorkedTimes,
                                           fullPeriod: Period)
    -> [ProjectID : TwoPartTimeReport] {
        var reports = [ProjectID : TwoPartTimeReport]()
        let ids: Set<ProjectID> = Set<ProjectID>(untilYesterday.keys).union(today.keys)
        for id in ids {
            let timeWorkedPreviousToToday: TimeInterval = untilYesterday[id] ?? 0.0
            let timeWorkedToday: TimeInterval = today[id] ?? 0.0
            reports[id] = TwoPartTimeReport(projectId: id,
                                            period: fullPeriod,
                                            workedTimeUntilDayBeforeRequest: timeWorkedPreviousToToday,
                                            workedTimeOnDayOfRequest: timeWorkedToday)
        }
        return reports
}

fileprivate struct ReportsService: Decodable {
    static func endpoint(workspaceId: WorkspaceID, since: String, until: String, userAgent: String) -> String {
        return "/reports/api/v2/summary?workspace_id=\(workspaceId)&since=\(since)&until=\(until)&grouping=projects&subgrouping=users&user_agent=\(userAgent)"
    }

    let reportEntries: [ReportEntry]

    private enum CodingKeys: String, CodingKey {
        case reportEntries = "data"
    }

    static func decodeReportEntries(data: Data, response: URLResponse) throws -> [ReportEntry] {
        return try JSONDecoder().decode(ReportsService.self, from: data).reportEntries
    }
}

fileprivate extension ReportsService {
    static func endpoint(with userAgent: String) -> (WorkspaceID, DayComponents, DayComponents) -> String {
        return { (workspaceId, since, until) in
            ReportsService.endpoint(workspaceId: workspaceId, since: since.iso8601String, until: until.iso8601String, userAgent: userAgent)
        }
    }
}
