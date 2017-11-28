//
//  Project.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

typealias ProjectID = Int64

struct Project: Decodable {
    let id: ProjectID
    let name: String?
    let active: Bool?
    let workspaceId: Int64?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case active
        case workspaceId = "wid"
    }
}

typealias IndexedProjects = [ProjectID : Project]
