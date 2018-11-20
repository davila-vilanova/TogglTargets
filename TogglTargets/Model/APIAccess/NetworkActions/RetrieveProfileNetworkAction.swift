//
//  RetrieveProfileNetworkAction.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

/// An `Action` that receives a URLSession configured with a credential to access the Toggl API and upon application
/// produces a Profile instance corresponding to the user credential or fails with an `APIAccessError`.
typealias RetrieveProfileNetworkAction = Action<URLSession, Profile, APIAccessError>

/// A function or closure that upon invocation creates and returns a RetrieveProfileNetworkAction.
typealias RetrieveProfileNetworkActionMaker = () -> RetrieveProfileNetworkAction

/// A concrete, non-mock implementation of `RetrieveProfileNetworkActionMaker`.
func makeRetrieveProfileNetworkAction() -> RetrieveProfileNetworkAction {
    return RetrieveProfileNetworkAction { session in
        session.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)
    }
}

/// Represents the data returned in the body of the response obtained by calling Toggl's profile endpoint with a valid
/// credential.
private struct MeService: Decodable {
    static let endpoint = "/api/v8/me"
    let profile: Profile

    private enum CodingKeys: String, CodingKey {
        case profile = "data"
    }

    static func decodeProfile(data: Data, response: URLResponse) throws -> Profile {
        return try JSONDecoder().decode(MeService.self, from: data).profile
    }
}
