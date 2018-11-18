//
//  Project.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
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
    var hashValue: Int {
        return id.hashValue ^ (name?.hashValue ?? 0) ^ (active?.hashValue ?? 0)
            ^ (workspaceId?.hashValue ?? 0) &* 16779163
    }
}
