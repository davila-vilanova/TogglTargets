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

            let collectProjectsOp = CollectionOperation<NetworkRetrieveProjectsOperation>() { [weak self] operations in
                for retrieveProjectsOp in operations {
                    if let retrievedProjects = retrieveProjectsOp.model {
                        self?.projects.value?.append(contentsOf: retrievedProjects)
                    }
                }

            }

            let spawnRetrievalOfProjectsOp =
                SpawningOperation<Workspace, [Project], CollectionOperation<NetworkRetrieveProjectsOperation>> (
                    inputRetrievalOperation:workspacesOp,
                    outputCollectionOperation: collectProjectsOp) { [weak self] workspace in
                        if let s = self {
                            return NetworkRetrieveProjectsOperation(credential: s.apiCredential, workspaceId: workspace.id)
                        }
                        return nil
            }

            let collectReportsOp = CollectionOperation<NetworkRetrieveReportsOperation>() { [weak self] operations in
                for retrieveReportsOp in operations {
                    if let retrievedReports = retrieveReportsOp.model,
                        let unwrappedSelf = self {
                        for (projectId, report) in retrievedReports {
                            let p = unwrappedSelf.reportPropertyForProjectId(projectId)
                            p.value = report
                        }
                    }
                }
            }

            let spawnRetrievalOfReportsOp =
                SpawningOperation<Workspace, Dictionary<Int64, TimeReport>, CollectionOperation<NetworkRetrieveReportsOperation>> (
                    inputRetrievalOperation: workspacesOp,
                    outputCollectionOperation: collectReportsOp) { [weak self] workspace in
                        if let s = self {
                            return NetworkRetrieveReportsOperation(credential: s.apiCredential, workspaceId: workspace.id)
                        }
                        return nil
            }

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
