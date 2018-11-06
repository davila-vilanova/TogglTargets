//
//  Project.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

typealias ProjectID = Int64

struct Project: Decodable {
    let id: ProjectID // swiftlint:disable:this identifier_name
    let name: String?
    let active: Bool?
    let workspaceId: WorkspaceID?

    private enum CodingKeys: String, CodingKey {
        case id // swiftlint:disable:this identifier_name
        case name
        case active
        case workspaceId = "wid"
    }
}

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
