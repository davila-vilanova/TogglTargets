//
//  Profile.swift
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
