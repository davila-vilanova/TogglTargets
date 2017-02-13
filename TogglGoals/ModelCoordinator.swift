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

    private func sortAndSetProjects(_ unsortedProjects: [Project]) {
        // TODO: clean up
        // TODO: sorting only takes place right after loading projects. Better if sorting happens also after editing goal.
        self.projects.value = unsortedProjects.sorted(by: { (p1, p2) -> Bool in
            let g1 = goalsStore.retrieveGoal(projectId: p1.id)
            let g2 = goalsStore.retrieveGoal(projectId: p2.id)

            if let hours1 = g1?.hoursPerMonth {
                if let hours2 = g2?.hoursPerMonth {
                    return hours1 >= hours2
                } else {
                    return true
                }
            } else {
                return g2?.hoursPerMonth == nil
            }
        })
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

            let retrieveProjectsOp =
                SpawningOperation<Workspace, [Project], NetworkRetrieveProjectsOperation>(
                    inputRetrievalOperation: workspacesOp,
                    spawnOperationMaker: { [credential = apiCredential] workspace in
                        NetworkRetrieveProjectsOperation(credential: credential, workspaceId: workspace.id)
                    },
                    collectionClosure: { [weak self] retrieveProjectsOps in
                        var allProjects = Array<Project>()
                        for retrieveProjectsOp in retrieveProjectsOps {
                            if let retrievedProjects = retrieveProjectsOp.model {
                                allProjects.append(contentsOf: retrievedProjects)
                            }
                        }

                        self?.sortAndSetProjects(allProjects)
                    })

            let retrieveReportsOp =
                SpawningOperation<Workspace, Dictionary<Int64, TimeReport>, NetworkRetrieveReportsOperation>(
                    inputRetrievalOperation: workspacesOp,
                    spawnOperationMaker: { [credential = apiCredential] workspace in
                        NetworkRetrieveReportsOperation(credential: credential, workspaceId: workspace.id)
                    },
                    collectionClosure: { [weak self] retrieveReportsOps in
                        for retrieveReportsOp in retrieveReportsOps {
                            if let retrievedReports = retrieveReportsOp.model,
                                let unwrappedSelf = self {
                                for (projectId, report) in retrievedReports {
                                    let p = unwrappedSelf.reportPropertyForProjectId(projectId)
                                    p.value = report
                                }
                            }
                        }
                    })


            networkQueue.addOperation(profileOp)
            networkQueue.addOperation(workspacesOp)
            networkQueue.addOperation(retrieveProjectsOp)
            networkQueue.addOperation(retrieveReportsOp)
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
