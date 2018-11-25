//
//  TimeReport.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
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

typealias WorkedTime = TimeInterval

/// Represents a report of time worked in a single `Project` during a defined `Period`, divided in two parts:
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

    /// The time worked from the start of the `Period` until the day before requesting the report, that is, until
    /// 'yesterday'.
    // TODO: rename to 'reference date'
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
    static func == (lhs: TwoPartTimeReport, rhs: TwoPartTimeReport) -> Bool {
        return lhs.projectId == rhs.projectId
            && lhs.period == rhs.period
            && lhs.workedTimeUntilDayBeforeRequest == rhs.workedTimeUntilDayBeforeRequest
            && lhs.workedTimeOnDayOfRequest == rhs.workedTimeOnDayOfRequest
    }
}

/// Returns a two part time report for the given project ID and for the proviced period, with the amount of worked time
/// set to zero.
///
/// - parameters:
///   - projectId: The ID of the project to associate with  this time report.
///   - period: The corresponding to associate with this time report.
///
/// - returns: A report for the provided project ID and period with the amount of worked time set to zero.
func makeZeroReport(for projectId: ProjectID, period: Period) -> TwoPartTimeReport {
    return TwoPartTimeReport(projectId: projectId,
                             period: period,
                             workedTimeUntilDayBeforeRequest: 0,
                             workedTimeOnDayOfRequest: 0)
}

/// The amount of time worked in a particular project as returned by the Toggl reports service.
struct ReportEntry: Decodable {
    let id: Int64 // swiftlint:disable:this identifier_name
    let time: TimeInterval
}

/// A dictionary of `TwoPartTimeReport` values indexed by their corresponding
/// project ID.
typealias IndexedTwoPartTimeReports = [ProjectID: TwoPartTimeReport]
