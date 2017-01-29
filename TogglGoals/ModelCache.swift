//
//  ModelCache.swift
//  TogglGoals
//
//  Created by David Davila on 27.01.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class ModelCache {
    private var userProfile: Profile?
    private var projects: [Project] = Array<Project>()
    private var workspaces: [Workspace] = Array<Workspace>()

    func retrieveUserProfile() -> (profile: Profile?, shouldRefresh: Bool) {
        return (userProfile, userProfile == nil)
    }

    func storeUserProfile(_ profile: Profile) {
        userProfile = profile
    }

    func storeWorkspaces(_ workspaces: [Workspace]) {
        self.workspaces = workspaces
    }

    func storeProjects(_ projects: [Project]) {
        self.projects = projects
    }
}
