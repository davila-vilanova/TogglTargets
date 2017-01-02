//
//  Project.swift
//  TogglGoals
//
//  Created by David Davila on 24/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

struct Profile {
    let id: Int64
    var name: String?
    var email: String?
    var imageUrl: URL?
    var timeZone:String?
    var workspaces = [Workspace]()
    var projects = [Project]()

    init(id: Int64) {
        self.id = id
    }
}

struct Workspace {
    let id: Int64
    var name: String?

    init(id: Int64) {
        self.id = id
    }
}

struct Project {
    let id: Int64
    var name: String?
    var active: Bool?
    var workspaceId: Int64?

    init(id: Int64) {
        self.id = id
    }
}

struct TimeGoal {
    var hoursPerMonth: Int?
    var workDaysPerWeek: Int?
}

struct TimeReport {
    let workedTime: TimeInterval?

    init(workedTime: TimeInterval) {
        self.workedTime = workedTime
    }
}
