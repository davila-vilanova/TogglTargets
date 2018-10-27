//
//  RunningEntry.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct RunningEntry: Decodable {
    let id: Int64
    let projectId: Int64
    let start: Date
    let retrieved: Date

    func runningTime(at pointInTime: Date) -> TimeInterval {
        return pointInTime.timeIntervalSince(start)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectId = "pid"
        case start
        case retrieved = "at"
    }
}

extension RunningEntry: Equatable {
    static func ==(lhs: RunningEntry, rhs: RunningEntry) -> Bool {
        return lhs.id == rhs.id && lhs.projectId == rhs.projectId && lhs.start == rhs.start
    }


}
