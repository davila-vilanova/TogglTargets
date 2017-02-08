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
    private let goalsStore: GoalsStore

    private let notificationCenter = NotificationCenter.default

    internal var profile = Property<Profile>(value: nil)
    internal var projects = Property<[Project]>(value: Array<Project>())
    internal var workspaces = Property<[Workspace]>(value: Array<Workspace>())

    private var reports = Property<[TimeReport]>(value: nil)

    private var goalProperties = Dictionary<Int64, Property<TimeGoal>>()
    private var observedGoalProperties = Dictionary<Int64, ObservedProperty<TimeGoal>>()

    private var reportProperties = Dictionary<Int64, Property<TimeReport>>()

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

    internal init(cache: ModelCache, goalsStore: GoalsStore) {
        self.cache = cache
        self.goalsStore = goalsStore
        super.init()
        retrieveUserProfile()
    }

    private func retrieveUserProfile() {
        let (profile, shouldRefresh) = self.cache.retrieveUserProfile()
        self.profile.value = profile
        if shouldRefresh {
            let profileOp = NetworkRetrieveProfileOperation(credential: apiCredential)
            profileOp.onSuccess = { profile in
                self.cache.storeUserProfile(profile)
                self.profile.value = profile
            }
            let workspacesOp = NetworkRetrieveWorkspacesOperation(credential: apiCredential)
            workspacesOp.onSuccess = { workspaces in
                self.cache.storeWorkspaces(workspaces)
                self.workspaces.value = workspaces
            }

            let collectProjectsOp = CollectRetrievedProjectsOperation()
            collectProjectsOp.completionBlock = { [weak self, weak collectProjectsOp] in
                if let collectedProjects = collectProjectsOp?.collectedProjects,
                    let s = self {
                    s.projects.value?.append(contentsOf: collectedProjects) // TODO: this works only if there's a unique load at startup
                }
            }

            let spawnRetrievalOfProjectsOp = SpawnRetrievalOfProjectsOperation(credential: apiCredential, collectRetrievedProjectsOperation: collectProjectsOp)

            let collectReportsOp = CollectRetrievedReportsOperation()
            collectReportsOp.completionBlock = { [weak self, weak collectReportsOp] in
                if let collectedReports = collectReportsOp?.collectedReports,
                    let s = self {
                    for (projectId, report) in collectedReports {
                        let p = s.reportPropertyForProjectId(projectId)
                        p.value = report
                    }
                }
            }
            let spawnRetrievalOfReportsOp = SpawnRetrievalOfReportsOperation(credential: apiCredential, collectRetrievedReportsOperation: collectReportsOp)

            spawnRetrievalOfProjectsOp.addDependency(workspacesOp)
            spawnRetrievalOfReportsOp.addDependency(workspacesOp)

            networkQueue.addOperation(profileOp)
            networkQueue.addOperation(workspacesOp)
            networkQueue.addOperation(spawnRetrievalOfProjectsOp)
            networkQueue.addOperation(collectProjectsOp)
            networkQueue.addOperation(spawnRetrievalOfReportsOp)
            networkQueue.addOperation(collectReportsOp)
        }
    }

    internal func goalPropertyForProjectId(_ projectId: Int64) -> Property<TimeGoal> {
        let goalProperty: Property<TimeGoal>

        if let existing = goalProperties[projectId] {
            goalProperty = existing
        } else {
            let goal = goalsStore.retrieveGoal(projectId: projectId)
            goalProperty = Property<TimeGoal>(value: goal)
            let observed = ObservedProperty(original: goalProperty, valueObserver: {[weak self] (goal) in
                Swift.print("modified goal=\(goal)")
                if let g = goal {
                    self?.goalsStore.storeGoal(goal: g)
                }
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

    internal func reportPropertyForProjectId(_ projectId: Int64) -> Property<TimeReport> {
        let reportProperty: Property<TimeReport>

        if let existing = reportProperties[projectId] {
            reportProperty = existing
        } else {
            reportProperty = Property<TimeReport>(value: nil)
            reportProperties[projectId] = reportProperty
        }

        return reportProperty
    }
}

protocol ModelCoordinatorContaining {
    var modelCoordinator: ModelCoordinator? { get set }
}
