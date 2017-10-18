//
//  TimeReport.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

protocol TimeReport {
    var projectId: Int64 { get }
    var since: DayComponents { get }
    var until: DayComponents { get }
    var workedTime: TimeInterval { get }
}

struct SingleTimeReport: TimeReport {
    let projectId: Int64
    let since: DayComponents
    let until: DayComponents
    let workedTime: TimeInterval
}

struct TwoPartTimeReport: TimeReport {
    let projectId: Int64
    let since: DayComponents
    let until: DayComponents
    var workedTime: TimeInterval {
        return workedTimeUntilYesterday + workedTimeToday
    }
    let workedTimeUntilYesterday: TimeInterval
    let workedTimeToday: TimeInterval
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
