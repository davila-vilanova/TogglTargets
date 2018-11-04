//
//  RetrieveProfileNetworkAction.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

typealias RetrieveProfileNetworkAction = Action<URLSession, Profile, APIAccessError>

typealias RetrieveProfileNetworkActionMaker = () -> RetrieveProfileNetworkAction

func makeRetrieveProfileNetworkAction() -> RetrieveProfileNetworkAction {
    return RetrieveProfileNetworkAction { session in
        session.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)
    }
}

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
