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
    let name: String?
    let email: String?
    let imageUrl: URL?
    let timeZone:String?
    let projects: [Project]

    init(id: Int64, name: String?, email: String?, imageUrl: URL?, timeZone: String?, projects: [Project] = [Project]()) {
        self.id = id
        self.name = name
        self.email = email
        self.imageUrl = imageUrl
        self.timeZone = timeZone
        self.projects = projects
    }
}

struct Project {
    let id: Int64
    let name: String?
    let clientName: String?
    let hexColor: String?
    let active: Bool

    init(id: Int64, name: String?, clientName: String?, hexColor: String?, active: Bool) {
        self.id = id
        self.name = name
        self.clientName = clientName
        self.hexColor = hexColor
        self.active = active
    }

    // TODO: needs workspace for the report
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
