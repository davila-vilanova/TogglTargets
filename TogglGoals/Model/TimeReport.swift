//
//  TimeReport.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

typealias WorkedTime = TimeInterval

protocol TimeReport {
    var projectId: Int64 { get }
    var since: DayComponents { get }
    var until: DayComponents { get }
    var workedTime: WorkedTime { get }
}

struct SingleTimeReport: TimeReport {
    let projectId: Int64
    let since: DayComponents
    let until: DayComponents
    let workedTime: WorkedTime
}

struct TwoPartTimeReport: TimeReport {
    let projectId: Int64
    let since: DayComponents
    let until: DayComponents
    var workedTime: WorkedTime {
        return workedTimeUntilYesterday + workedTimeToday
    }
    let workedTimeUntilYesterday: WorkedTime
    let workedTimeToday: WorkedTime
}

extension SingleTimeReport: CustomDebugStringConvertible {
    var debugDescription: String {
        return "SingleTimeReport(workedTime: \(workedTime))";
    }
}

extension TwoPartTimeReport: CustomDebugStringConvertible {
    var debugDescription: String {
        return "TwoPartTimeReport(untilYesterday: \(workedTimeUntilYesterday), today: \(workedTimeToday)";
    }
}

extension TwoPartTimeReport: Equatable {
    static func ==(lhs: TwoPartTimeReport, rhs: TwoPartTimeReport) -> Bool {
        return lhs.projectId == rhs.projectId
            && lhs.since == rhs.since
            && lhs.until == rhs.until
            && lhs.workedTimeUntilYesterday == rhs.workedTimeUntilYesterday
            && lhs.workedTimeToday == rhs.workedTimeToday
    }
}
