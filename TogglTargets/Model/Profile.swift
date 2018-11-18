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
    /// The ID of the user in the Toggl platform.
    let id: Int64 // swiftlint:disable:this identifier_name

    /// The user's full name.
    let name: String?

    /// The user's email address.
    let email: String

    /// URL of an image associated with the user's profile.
    let imageUrl: URL?

    /// The timezone for this user as set in the Toggl platform.
    let timezone: String?

    /// The workspaces associated with the user account. Hopefully one or more.
    let workspaces: [Workspace]

    /// The API access token associated with the user account.
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
    /// The ID of the workspace in the Toggl platform.
    let id: WorkspaceID // swiftlint:disable:this identifier_name

    /// The name of the workspace in the Toggl platform.
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
