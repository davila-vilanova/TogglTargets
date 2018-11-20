//
//  RetrieveRunningEntryNetworkAction.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
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
    static let endpoint = "/api/v8/time_entries/current"

    let runningEntry: RunningEntry?

    private enum CodingKeys: String, CodingKey {
        case runningEntry = "data"
    }

    static func decodeRunningEntry(data: Data, response: URLResponse) throws -> RunningEntry? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RunningEntryService.self, from: data).runningEntry
    }
}
