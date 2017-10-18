//
//  Profile.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct Profile: Decodable {
    let id: Int64
    let name: String?
    let email: String?
    let imageUrl: URL?
    let timezone:String?
    let workspaces: [Workspace]

    private enum CodingKeys: String, CodingKey {
        case id
        case name = "fullname"
        case email
        case imageUrl = "image_url"
        case timezone
        case workspaces
    }
}

struct Workspace: Decodable {
    let id: Int64
    let name: String?
}
