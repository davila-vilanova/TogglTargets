//
//  RunningEntry.swift
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

/// Represents a time entry which is currently running in the Toggl service.
struct RunningEntry: Decodable {
    /// The ID of the time entry
    let id: Int64 // swiftlint:disable:this identifier_name

    /// The ID of the project associated with this time entry.
    let projectId: ProjectID?

    /// The point in time at which this time entry started.
    let start: Date

    /// The point in time at which this time entry was retrieved.
    let retrieved: Date

    /// Determines the duration of this running time entry as of the moment in time represented by the provided date.
    ///
    /// - parameters:
    ///   - pointInTime: The point in time used to calculate the duration of this entry.
    ///
    /// - returns: The amount of time elapsed from the start of the time entry until the provided date.
    func runningTime(at pointInTime: Date) -> TimeInterval {
        return pointInTime.timeIntervalSince(start)
    }

    private enum CodingKeys: String, CodingKey {
        case id // swiftlint:disable:this identifier_name
        case projectId = "pid"
        case start
        case retrieved = "at"
    }
}

extension RunningEntry: Equatable {
    static func == (lhs: RunningEntry, rhs: RunningEntry) -> Bool {
        return lhs.id == rhs.id && lhs.projectId == rhs.projectId && lhs.start == rhs.start
    }

}
