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

    init(id: Int64) {
        self.id = id
    }
}

typealias StringKeyedDictionary = Dictionary<String, Any>

extension Profile {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Profile? {
        if let id = dictionary["id"] as? Int64 {
            var profile = Profile(id: id)
            if let name = dictionary["fullname"] as? String {
                profile.name = name
            }
            if let email = dictionary["email"] as? String {
                profile.email = email
            }
            if let imageUrlString = dictionary["image_url"] as? String,
                let imageUrl = URL(string: imageUrlString) {
                profile.imageUrl = imageUrl
            }

            return profile
        } else {
            return nil
        }
    }
}

struct Workspace {
    let id: Int64
    var name: String?

    init(id: Int64) {
        self.id = id
    }
}

extension Workspace {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Workspace? {
        if let id = dictionary["id"] as? Int64 {
            var workspace = Workspace(id: id)
            if let name = dictionary["name"] as? String {
                workspace.name = name
            }
            return workspace
        } else {
            return nil
        }
    }

    static func collectionFromTogglAPI(dictionary: StringKeyedDictionary) -> [Workspace] {
        var workspaces = Array<Workspace>()
        if let workspacesDictionaries = dictionary["workspaces"] as? [StringKeyedDictionary] {
            for workspaceDictionary in workspacesDictionaries {
                if let workspace = Workspace.fromTogglAPI(dictionary: workspaceDictionary) {
                    workspaces.append(workspace)
                }
            }
        }
        return workspaces
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

extension Project {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Project? {
        if let id = dictionary["id"] as? Int64 {
            var project = Project(id: id)
            if let name = dictionary["name"] as? String {
                project.name = name
            }
            if let active = dictionary["active"] as? Bool {
                project.active = active
            }
            if let workspaceId = dictionary["wid"] as? Int64 {
                project.workspaceId = workspaceId
            }
            return project
        }
        return nil
    }

    static func collectionFromTogglAPI(dictionary: StringKeyedDictionary) -> [Project] {
        var projects = Array<Project>()
        if let projectsDictionaries = dictionary["projects"] as? [StringKeyedDictionary] {
            for projectDictionary in projectsDictionaries {
                if let project = Project.fromTogglAPI(dictionary: projectDictionary) {
                    projects.append(project)
                }
            }
        }
        return projects
    }
}


struct TimeGoal {
    let projectId: Int64
    var hoursPerMonth: Int?
    var workDaysPerWeek: Int?

    init(forProjectId projectId: Int64) {
        self.projectId = projectId
    }
}

struct TimeReport {
    let projectId: Int64
    let workedTime: TimeInterval

    init(projectId: Int64, workedTime: TimeInterval) {
        self.projectId = projectId
        self.workedTime = workedTime
    }
}
