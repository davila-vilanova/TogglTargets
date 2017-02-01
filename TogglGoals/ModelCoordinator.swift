//
//  ModelCoordinator.swift
//  TogglGoals
//
//  Created by David Davila on 26/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Foundation

// ModelCoordinator is not thread safe
internal class ModelCoordinator: NSObject {
    private let cache: ModelCache
    private let notificationCenter = NotificationCenter.default

    internal var profile = Property<Profile>(value: nil)
    internal var projects = Property<[Project]>(value: Array<Project>())
    internal var workspaces = Property<[Workspace]>(value: Array<Workspace>())

    private var goalProperties = Dictionary<Int64, Property<TimeGoal>>()
    private var observedGoalProperties = Dictionary<Int64, ObservedProperty<TimeGoal>>()

    private let apiCredential = TogglAPICredential()

    // TODO: inject these two?
    private lazy var mainQueue: DispatchQueue = {
        return DispatchQueue.main
    }()

    private lazy var networkQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "NetworkQueue"
        return q
    }()


    internal init(cache: ModelCache) {
        self.cache = cache
        super.init()
        retrieveUserProfile()
    }

    private func retrieveUserProfile() {
        let (profile, shouldRefresh) = self.cache.retrieveUserProfile()
        self.profile.value = profile
        if shouldRefresh {
            let op = ProfileLoadingOperation(credential: apiCredential)
            op.completionBlock = {
                if let profile = op.model?.0 {
                    self.cache.storeUserProfile(profile)
                    self.profile.value = profile
                }
                if let workspaces = op.model?.1 {
                    self.cache.storeWorkspaces(workspaces)
                    self.workspaces.value = workspaces
                }
                if let projects = op.model?.2 {
                    self.cache.storeProjects(projects)
                    self.projects.value = projects
                }
            }
            networkQueue.addOperation(op)
        }
    }

    internal func goalPropertyForProjectId(_ projectId: Int64) -> Property<TimeGoal> {
        let goalProperty: Property<TimeGoal>

        if let existing = goalProperties[projectId] {
            goalProperty = existing
        } else {
            goalProperty = Property<TimeGoal>(value: retrieveGoal(projectId: projectId))
            let observed = ObservedProperty(original: goalProperty, valueObserver: { (goal) in
                Swift.print("modified goal=\(goal)")
            }, invalidationObserver: { 
                Swift.print("invalidated goal projectId=\(projectId)")
            })
            observedGoalProperties[projectId] = observed
            goalProperties[projectId] = goalProperty
        }

        return goalProperty
    }

    internal func initializeGoal(_ goal: TimeGoal) {
        let p = goalPropertyForProjectId(goal.projectId)
        p.value = goal
    }

    private var goals = Dictionary<Int64, TimeGoal>()
    private func retrieveGoal(projectId: Int64) -> TimeGoal? {
        return goals[projectId]
    }
    private func storeGoal(goal: TimeGoal) {
        goals[goal.projectId] = goal
    }
}

protocol ModelCoordinatorContaining {
    var modelCoordinator: ModelCoordinator? { get set }
}
