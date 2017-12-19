//
//  RetrieveReportsNetworkAction.swift
//  TogglGoals
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

typealias IndexedTwoPartTimeReports = [ProjectID : TwoPartTimeReport]
typealias RetrieveReportsNetworkAction =
    Action<([WorkspaceID], TwoPartTimeReportPeriod), IndexedTwoPartTimeReports, APIAccessError>
typealias RetrieveReportsNetworkActionMaker = (Property<URLSession?>) -> RetrieveReportsNetworkAction

func makeRetrieveReportsNetworkAction(_ urlSession: Property<URLSession?>) -> RetrieveReportsNetworkAction {
    return RetrieveReportsNetworkAction(unwrapping: urlSession) { (session, inputs) in
        let (workspaceIDs, period) = inputs
        let workedUntilYesterday = workedTimesProducer(session: session, workspaceIDs: workspaceIDs, period: period.previousToDayOfRequest)
        let workedToday = workedTimesProducer(session: session, workspaceIDs: workspaceIDs, period: period.forDayOfRequest)
        return SignalProducer.combineLatest(workedUntilYesterday, workedToday, SignalProducer(value: period.scope))
            .map(generateIndexedReportsFromWorkedTimes)
    }
}

fileprivate let UserAgent = "david@davi.la"

typealias IndexedWorkedTimes = [ProjectID : WorkedTime]

fileprivate func workedTimesProducer(session: URLSession, workspaceIDs: [WorkspaceID], period: Period?)
    -> SignalProducer<IndexedWorkedTimes, APIAccessError> {
        guard session.canAccessTogglReportsAPI else {
            assert(false, "Session is not suitable for accessing the Toggl API") // TODO: codify in type?
            return SignalProducer(value: IndexedWorkedTimes()) // empty
        }
        guard let period = period else {
            return SignalProducer(value: IndexedWorkedTimes()) // empty
        }

        func timesProducer(forSingle workspaceID: WorkspaceID) -> SignalProducer<IndexedWorkedTimes, APIAccessError> {
            let endpoint =
                ReportsService.endpoint(workspaceId: workspaceID,
                                        since: period.start.iso8601String, until: period.end.iso8601String,
                                        userAgent: UserAgent)
            return session.togglAPIRequestProducer(for: endpoint, decoder: ReportsService.decodeReportEntries)
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
    -> [Int64 : TwoPartTimeReport] {
        var reports = [Int64 : TwoPartTimeReport]()
        let ids: Set<Int64> = Set<Int64>(untilYesterday.keys).union(today.keys)
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
    static func endpoint(workspaceId: Int64, since: String, until: String, userAgent: String) -> String {
        return "/reports/api/v2/summary?workspace_id=\(workspaceId)&since=\(since)&until=\(until)&grouping=projects&subgrouping=users&user_agent=\(userAgent)"
    }

    let reportEntries: [ReportEntry]
    struct ReportEntry: Decodable {
        let id: Int64
        let time: TimeInterval
    }

    private enum CodingKeys: String, CodingKey {
        case reportEntries = "data"
    }

    static func decodeReportEntries(data: Data, response: URLResponse) throws -> [ReportsService.ReportEntry] {
        return try JSONDecoder().decode(ReportsService.self, from: data).reportEntries
    }
}

fileprivate extension ReportsService {
    static func endpoint(with userAgent: String) -> (Int64, DayComponents, DayComponents) -> String {
        return { (workspaceId, since, until) in
            ReportsService.endpoint(workspaceId: workspaceId, since: since.iso8601String, until: until.iso8601String, userAgent: userAgent)
        }
    }
}
