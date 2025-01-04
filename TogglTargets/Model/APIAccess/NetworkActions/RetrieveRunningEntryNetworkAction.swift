//
//  RetrieveRunningEntryNetworkAction.swift
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

/// Action that retrieves from the Toggl API the currently running time entry.
/// Produces a nil value if no time entry is currently running.
typealias RetrieveRunningEntryNetworkAction = Action<Void, RunningEntry?, APIAccessError>

/// A function or closure that takes a `Property` that holds and tracks changes  to a `URLSession` optional value and
/// generates a `RetrieveRunningEntryNetworkAction` that is enabled whenever the the provided `Property` holds a
/// non-`nil` value.
///
/// This can be used to inject a `RetrieveRunningEntryNetworkAction` into an entity that needs to make the `Action`
/// depend on the state of its `URLSession`.
typealias RetrieveRunningEntryNetworkActionMaker = (Property<URLSession?>) -> RetrieveRunningEntryNetworkAction

/// A concrete, non-mock implementation of `RetrieveRunningEntryNetworkActionMaker`.
func makeRetrieveRunningEntryNetworkAction(_ urlSession: Property<URLSession?>) -> RetrieveRunningEntryNetworkAction {
    return RetrieveRunningEntryNetworkAction(unwrapping: urlSession) { (session, _) in
        return session.togglAPIRequestProducer(for: RunningEntryService.endpoint,
                                               decoder: RunningEntryService.decodeRunningEntry)
    }
}

/// Represents the data returned in the body of the response obtained by calling Toggl's current time entry endpoint
/// with a valid credential.
private struct RunningEntryService: Decodable {
    static let endpoint = "/api/v9/me/time_entries/current"

    let runningEntry: RunningEntry?

    private enum CodingKeys: String, CodingKey {
        case runningEntry = "data"
    }

    static func decodeRunningEntry(data: Data, response: URLResponse) throws -> RunningEntry? {
        guard String(data: data, encoding: .utf8) != "null" else {
            return nil
        }
        let decoder = JSONDecoder()
        return try decoder.decode(RunningEntry.self, from: data)
    }
}
