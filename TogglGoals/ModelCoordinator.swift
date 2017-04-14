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
    internal let runningEntry = Property<RunningEntry>(value: nil)
    internal var runningEntryRefreshTimer: Timer?

    private var goalProperties = Dictionary<Int64, Property<TimeGoal>>()
    private var observedGoalProperties = Dictionary<Int64, ObservedProperty<TimeGoal>>()

    private var reportProperties = Dictionary<Int64, Property<TwoPartTimeReport>>()

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
        self.cache = cache
        self.goalsStore = goalsStore
        super.init()
        retrieveUserDataFromToggl()
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
    private func retrieveUserDataFromToggl() {
        let retrieveProfileOp = NetworkRetrieveProfileOperation(credential: apiCredential)
        retrieveProfileOp.onSuccess = { profile in
            self.profile.value = profile
        }

        let retrieveWorkspacesOp = NetworkRetrieveWorkspacesOperation(credential: apiCredential)

        let retrieveProjectsOp = NetworkRetrieveProjectsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential) {
            [weak projectsProperty = self.projects] (retrievedProjects) in
            guard let p = projectsProperty else {
                return
            }
            p.value = retrievedProjects
        }

        let retrieveReportsOp = NetworkRetrieveReportsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential, calendar: calendar) { [weak self] (collectedReports) in
            guard let s = self else {
                return
            }
            for (projectId, report) in collectedReports {
                s.reportPropertyForProjectId(projectId).value = report
            }
        }
        
        networkQueue.addOperation(retrieveProfileOp)
        networkQueue.addOperation(retrieveWorkspacesOp)
        networkQueue.addOperation(retrieveProjectsOp)
        networkQueue.addOperation(retrieveReportsOp)
    }

    internal func goalPropertyForProjectId(_ projectId: Int64) -> Property<TimeGoal> {
        let goalProperty: Property<TimeGoal>

        if let existing = goalProperties[projectId] {
            goalProperty = existing
        } else {
            let goal = goalsStore.retrieveGoal(projectId: projectId)
            goalProperty = Property<TimeGoal>(value: goal)
            let observed = ObservedProperty(original: goalProperty, valueObserver: {[weak self] (goal) in
                Swift.print("modified goal=\(String(describing: goal))")
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

    internal func reportPropertyForProjectId(_ projectId: Int64) -> Property<TwoPartTimeReport> {
        let reportProperty: Property<TwoPartTimeReport>

        if let existing = reportProperties[projectId] {
            reportProperty = existing
        } else {
            reportProperty = Property<TwoPartTimeReport>(value: nil)
            reportProperties[projectId] = reportProperty
        }

        return reportProperty
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


