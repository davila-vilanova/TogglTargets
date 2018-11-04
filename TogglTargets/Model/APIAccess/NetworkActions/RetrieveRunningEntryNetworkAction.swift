//
//  RetrieveRunningEntryNetworkAction.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

typealias RetrieveRunningEntryNetworkAction = Action<Void, RunningEntry?, APIAccessError>

typealias RetrieveRunningEntryNetworkActionMaker = (Property<URLSession?>) -> RetrieveRunningEntryNetworkAction

func makeRetrieveRunningEntryNetworkAction(_ urlSession: Property<URLSession?>) -> RetrieveRunningEntryNetworkAction {
    return RetrieveRunningEntryNetworkAction(unwrapping: urlSession) { (session, _) in
        return session.togglAPIRequestProducer(for: RunningEntryService.endpoint, decoder: RunningEntryService.decodeRunningEntry)
    }
}

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
