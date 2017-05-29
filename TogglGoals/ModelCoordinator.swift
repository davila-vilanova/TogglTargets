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
    
    private var observedGoals = Dictionary<Int64, ObservedProperty<TimeGoal>>()
    
    private var reportProperties = Dictionary<Int64, Property<TwoPartTimeReport>>()
    
    internal let runningEntry = Property<RunningEntry>(value: nil)
    internal var runningEntryRefreshTimer: Timer?

    private let apiCredential = TogglAPICredential()

    private let now = Date()
    private let startOfPeriod: DayComponents
    private let yesterday: DayComponents?
    private let today: DayComponents

    
    // TODO: inject these three?
    private lazy var mainQueue: DispatchQueue = {
        return DispatchQueue.main
    }()

    private lazy var networkQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "NetworkQueue"
        return q
    }()

    private var calendar: Calendar

    internal init(cache: ModelCache, goalsStore: GoalsStore) {
        self.goalsStore = goalsStore
        
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.current // TODO: get from user profile
        self.calendar = calendar

        startOfPeriod = calendar.firstDayOfMonth(for: now)
        yesterday = try? calendar.previousDay(for: now, notBefore: startOfPeriod)
        today = calendar.dayComponents(from: now)
        
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
        let retrieveReportsOp = NetworkRetrieveReportsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential, startOfPeriod: startOfPeriod, yesterday: yesterday, today: today)

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

    // MARK: - Goals
    
    internal func goalProperty(for projectId: Int64) -> Property<TimeGoal> {
        let goalProperty = goalsStore.goalProperty(for: projectId)
        observedGoals[projectId] =
            ObservedProperty<TimeGoal>(original: goalProperty,
                                       valueObserver: { [weak self] observedGoal in
                                        self?.goalChanged(for: projectId)
                },
                                       invalidationObserver: { [weak self] in
                                        self?.observedGoals.removeValue(forKey: projectId)
            })
        return goalProperty
    }
    
    internal func setNewGoal(_ goal: TimeGoal) {
        goalsStore.storeNew(goal: goal)
    }

    internal func deleteGoal(_ goal: TimeGoal) {
        goalsStore.deleteGoal(goal)
    }

    private func goalChanged(for projectId: Int64) {
        guard var projects = self.projects.value else {
            return
        }
        let indexPaths = projects.moveProjectAfterGoalChange(projectId: projectId)!
        let clue = CollectionUpdateClue(itemMovedFrom: indexPaths.0, to: indexPaths.1)
        self.projects.collectionUpdateClue = clue
        self.projects.value = projects
    }

    // MARK: -
    
    internal func reportProperty(for projectId: Int64) -> Property<TwoPartTimeReport> {
        if let property = reportProperties[projectId] {
            return property
        } else {
            let zeroTimeReport = TwoPartTimeReport(projectId: projectId, since: startOfPeriod, until: today, workedTimeUntilYesterday: 0, workedTimeToday: 0)
            let property = Property<TwoPartTimeReport>(value: zeroTimeReport)
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
