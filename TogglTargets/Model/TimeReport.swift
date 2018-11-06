//
//  TimeReport.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

typealias WorkedTime = TimeInterval

/// Represents a report of time worked in a single `Project` during a defined `Period`,
/// divided in two parts:
/// 1: The time worked from the start of the `Period` until the day before the report is requested,
/// 2: The time worked on the day the report is requested.
struct TwoPartTimeReport {

    /// The ID of the project corresponding to this report
    let projectId: ProjectID

    /// The `Period` of time to which this report is scoped.
    let period: Period

    /// The total worked time represented by this report.
    var workedTime: WorkedTime {
        return workedTimeUntilDayBeforeRequest + workedTimeOnDayOfRequest
    }

    /// The time worked from the start of the `Period` until the day before requesting the report,
    /// that is, until 'yesterday'.
    let workedTimeUntilDayBeforeRequest: WorkedTime

    /// The time worked on the day the report is requested, that is, 'today'.
    let workedTimeOnDayOfRequest: WorkedTime
}

extension TwoPartTimeReport: CustomDebugStringConvertible {
    var debugDescription: String {
        return "TwoPartTimeReport(workedTimeUntilDayBeforeRequest: \(workedTimeUntilDayBeforeRequest), "
            + "workedTimeOnDayOfRequest: \(workedTimeOnDayOfRequest))"
    }
}

extension TwoPartTimeReport: Equatable {
    static func ==(lhs: TwoPartTimeReport, rhs: TwoPartTimeReport) -> Bool {
        return lhs.projectId == rhs.projectId
            && lhs.period == rhs.period
            && lhs.workedTimeUntilDayBeforeRequest == rhs.workedTimeUntilDayBeforeRequest
            && lhs.workedTimeOnDayOfRequest == rhs.workedTimeOnDayOfRequest
    }
}

func makeZeroReport(for projectId: ProjectID, period: Period) -> TwoPartTimeReport {
    return TwoPartTimeReport(projectId: projectId,
                             period: period,
                             workedTimeUntilDayBeforeRequest: 0,
                             workedTimeOnDayOfRequest: 0)
}

struct ReportEntry: Decodable {
    let id: Int64
    let time: TimeInterval
}

/// A dictionary of `TwoPartTimeReport` values indexed by their corresponding
/// project ID.
typealias IndexedTwoPartTimeReports = [ProjectID: TwoPartTimeReport]
