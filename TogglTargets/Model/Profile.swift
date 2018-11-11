//
//  Profile.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

/// Represents the user's profile as retrieved from the Toggl API.
struct Profile: Decodable {
    let id: Int64 // swiftlint:disable:this identifier_name
    let name: String?
    let email: String
    let imageUrl: URL?
    let timezone: String?
    let workspaces: [Workspace]
    let apiToken: String?
    // TODO: some properties don't need to be optional

    private enum CodingKeys: String, CodingKey {
        case id // swiftlint:disable:this identifier_name
        case name = "fullname"
        case email
        case imageUrl = "image_url"
        case timezone
        case workspaces
        case apiToken = "api_token"
    }
}

extension Profile: Equatable {
    static func == (lhs: Profile, rhs: Profile) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.email == rhs.email
            && lhs.imageUrl == rhs.imageUrl
            && lhs.timezone == rhs.timezone
            && Set<Workspace>(lhs.workspaces) == Set<Workspace>(rhs.workspaces)
            && lhs.apiToken == rhs.apiToken
    }
}

typealias WorkspaceID = Int64

/// Represents a workspace in the Toggl API.
struct Workspace: Decodable {
    let id: WorkspaceID // swiftlint:disable:this identifier_name
    let name: String?
}

extension Workspace: Equatable {
    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

extension Workspace: Hashable {
    var hashValue: Int {
        return id.hashValue ^ (name?.hashValue ?? 0) &* 16779163
    }
}
