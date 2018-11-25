//
//  RetrieveProfileNetworkAction.swift
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
