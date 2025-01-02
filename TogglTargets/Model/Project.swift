//
//  Project.swift
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

typealias ProjectID = Int64

/// Represents a project entity retrieved from the Toggl API.
struct Project: Decodable {
    /// The ID of the project in the Toggl platform.
    let id: ProjectID // swiftlint:disable:this identifier_name

    /// The name of the project in the Toggl platform.
    let name: String?

    /// Whether the project is currently active or not, as set in the Toggl platform.
    let active: Bool?

    /// The workspace ID to which this project is associated.
    let workspaceId: WorkspaceID?
    // TODO: some properties don't need to be optional

    private enum CodingKeys: String, CodingKey {
        case id // swiftlint:disable:this identifier_name
        case name
        case active
        case workspaceId = "wid"
    }
}

/// A collection of projects indexed by project ID
typealias IndexedProjects = [ProjectID: Project]

extension Project: Equatable {
    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.active == rhs.active
            && lhs.workspaceId == rhs.workspaceId
    }
}

extension Project: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(active)
        hasher.combine(workspaceId)
    }
}
