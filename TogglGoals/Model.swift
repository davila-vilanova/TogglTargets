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
            if let workspacesDictionaries = dictionary["workspaces"] as? [StringKeyedDictionary] {
                var workspaces = Array<Workspace>()
                for workspaceDictionary in workspacesDictionaries {
                    if let workspace = Workspace.fromTogglAPI(dictionary: workspaceDictionary) {
                        workspaces.append(workspace)
                    }
                }
            } // TODO: collapse these two into a generic function having Workpace and Project conform to a protocol that declares fromTogglAPI(dictionary:) -> (Protocol)
            if let projectsDictionaries = dictionary["projects"] as? [StringKeyedDictionary] {
                var projects = Array<Project>()
                for projectDictionary in projectsDictionaries {
                    if let project = Project.fromTogglAPI(dictionary: projectDictionary) {
                        projects.append(project)
                    }
                }
                profile.projects = projects
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
