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
    private let goalsStore: GoalsStore

    internal var profileProperty = Property<Profile>(value: nil)
    internal var projects = Property<ProjectsByGoals>(value: nil)
    
    private var reportProperties = Dictionary<Int64, Property<TwoPartTimeReport>>()
    
    internal let runningEntry = Property<RunningEntry>(value: nil)
    internal var runningEntryRefreshTimer: Timer?

    private let apiCredential = TogglAPICredential()

    // TODO: inject these three?
    private lazy var mainQueue: DispatchQueue = {
        return DispatchQueue.main
    }()

    private lazy var networkQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "NetworkQueue"
        return q
    }()

    private lazy var calendar: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current // TODO: get from user profile
        return cal
    }()

    internal init(cache: ModelCache, goalsStore: GoalsStore) {
        self.goalsStore = goalsStore
        super.init()
        retrieveUserDataFromToggl()
    }

    private func retrieveUserDataFromToggl() {
        let retrieveProfileOp = NetworkRetrieveProfileOperation(credential: apiCredential)
        retrieveProfileOp.onSuccess = { profile in
            self.profileProperty.value = profile
        }

        let retrieveWorkspacesOp = NetworkRetrieveWorkspacesOperation(credential: apiCredential)

        let retrieveProjectsOp = NetworkRetrieveProjectsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential)
        let retrieveReportsOp = NetworkRetrieveReportsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential, calendar: calendar)

        retrieveProjectsOp.outputCollectionOperation.completionBlock = { [weak self] in
            if let projects = retrieveProjectsOp.outputCollectionOperation.collectedOutput {
                guard let s = self else {
                    return
                }
                s.projects.value = ProjectsByGoals(projects: projects, goalsStore: s.goalsStore)
            }
        }

        retrieveReportsOp.outputCollectionOperation.completionBlock = { [weak self] in
            if let reports = retrieveReportsOp.outputCollectionOperation.collectedOutput {
                for (projectId, report) in reports {
                    self?.reportProperties[projectId] = Property(value: report)
                }
            }
        }
        
        networkQueue.addOperation(retrieveProfileOp)
        networkQueue.addOperation(retrieveWorkspacesOp)
        networkQueue.addOperation(retrieveProjectsOp)
        networkQueue.addOperation(retrieveReportsOp)
    }
    
    internal func goalProperty(for projectId: Int64) -> Property<TimeGoal> {
        return goalsStore.goalProperty(for: projectId)
    }
    
    internal func setNewGoal(_ goal: TimeGoal) {
        goalsStore.storeNew(goal: goal)
        guard var projects = self.projects.value else {
            return
        }
        let indexPaths = projects.moveProjectAfterGoalChange(projectId: goal.projectId)!
        let clue = CollectionUpdateClue(itemMovedFrom: indexPaths.0, to: indexPaths.1)
        self.projects.collectionUpdateClue = clue
        self.projects.value = projects
    }

    internal func deleteGoal(_ goal: TimeGoal) {
        goalsStore.deleteGoal(goal)
        guard var projects = self.projects.value else {
            return
        }
        let indexPaths = projects.moveProjectAfterGoalChange(projectId: goal.projectId)!
        let clue = CollectionUpdateClue(itemMovedFrom: indexPaths.0, to: indexPaths.1)
        self.projects.collectionUpdateClue = clue
        self.projects.value = projects
    }
    
    internal func reportProperty(for projectId: Int64) -> Property<TwoPartTimeReport> {
        if let property = reportProperties[projectId] {
            return property
        } else {
            let property = Property<TwoPartTimeReport>(value: nil)
            reportProperties[projectId] = property
            return property
        }
    }
    
    func refreshRunningTimeEntry() {
        retrieveRunningTimeEntry()
        if let oldTimer = runningEntryRefreshTimer,
            oldTimer.isValid {
            oldTimer.invalidate()
        }
        runningEntryRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true, block: { [weak self] (timer) in
            guard let s = self else {
                return
            }
            s.retrieveRunningTimeEntry()
        })
    }

    internal func stopRefreshingRunningTimeEntry() {
        guard let timer = runningEntryRefreshTimer else {
            return
        }
        if timer.isValid {
            timer.invalidate()
        }
        runningEntryRefreshTimer = nil
    }

    private func retrieveRunningTimeEntry() {
        let op = NetworkRetrieveRunningEntryOperation(credential: apiCredential)
        op.onSuccess = { runningEntry in
            self.runningEntry.value = runningEntry
        }
        networkQueue.addOperation(op)
    }
}

protocol ModelCoordinatorContaining {
    var modelCoordinator: ModelCoordinator? { get set }
}

extension ProjectsByGoals {
    init(projects: Dictionary<Int64, Project>, goalsStore: GoalsStore) {
        let hasGoal = { [weak goalsStore] (projectId: Int64) -> Bool in
            guard let store = goalsStore else {
                return false
            }
            return store.goalExists(for: projectId)
        }
        let areGoalsInIncreasingOrder = { [weak goalsStore] (id0: Int64, id1: Int64) -> Bool in
            let goal0 = goalsStore?.goalProperty(for: id0).value,
            goal1 = goalsStore?.goalProperty(for: id1).value
            if goal0 != nil, goal1 == nil {
                // a project with goal comes before a project without it
                return true
            } else if let hoursPerMonth0 = goal0?.hoursPerMonth,
                let hoursPerMonth1 = goal1?.hoursPerMonth {
                // when two projects have goals the one with the larger goal comes first
                return hoursPerMonth0 > hoursPerMonth1
            } else {
                return false
            }
        }
        
        self.init(projects: projects, hasGoal: hasGoal, areGoalsInIncreasingOrder: areGoalsInIncreasingOrder)
    }
}
