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

    internal var profile = Property<Profile>(value: nil)
    private var projects = Dictionary<Int64, Project>() {
        didSet {
            let projectIds = [Int64](projects.keys)
            sortedProjectIds = projectIds.sorted { id0, id1 in
                let goal0 = goalsStore.retrieveGoal(projectId: id0),
                goal1 = goalsStore.retrieveGoal(projectId: id1)
                // a project with goal comes before a project without it
                if goal0 != nil, goal1 == nil {
                    return true
                } else if goal0 == nil, goal1 != nil {
                    return false
                }
                
                // when two projects have goals the one with the larger goal comes first
                return goal0!.hoursPerMonth > goal1!.hoursPerMonth
            }
        }
    }
    
    internal var sortedProjectIds = [Int64]() {
        didSet {
            let indexOfLastProjectWithGoal = sortedProjectIds.binarySearch { (projectId) -> Bool in
                goalsStore.retrieveGoal(projectId: projectId) != nil
            }
            idsOfProjectsWithGoals = sortedProjectIds.prefix(indexOfLastProjectWithGoal)
            idsOfProjectsWithoutGoals = sortedProjectIds.suffix(sortedProjectIds.count - indexOfLastProjectWithGoal)
        }
    }
    internal var idsOfProjectsWithGoals = ArraySlice<Int64>()
    internal var idsOfProjectsWithoutGoals = ArraySlice<Int64>()
    
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
            self.profile.value = profile
        }

        let retrieveWorkspacesOp = NetworkRetrieveWorkspacesOperation(credential: apiCredential)

        let retrieveProjectsOp = NetworkRetrieveProjectsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential)
        let retrieveReportsOp = NetworkRetrieveReportsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential, calendar: calendar)
        
       let troikasCollectingOperation = ProjectsGoalsReportsCollectingOperation(retrieveProjectsOperation: retrieveProjectsOp, retrieveReportsOperation: retrieveReportsOp, goalStore: goalsStore) { [weak self] troikas in
            self?.projects = troikas
        }
        
        networkQueue.addOperation(retrieveProfileOp)
        networkQueue.addOperation(retrieveWorkspacesOp)
        networkQueue.addOperation(retrieveProjectsOp)
        networkQueue.addOperation(retrieveReportsOp)
        networkQueue.addOperation(troikasCollectingOperation)
    }

    internal func setGoal(_ goal: TimeGoal) {
        guard let troika = projects[goal.projectId] else {
            return
        }
        troika.goal.value = goal
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

extension Collection {
    /// Finds such index N that predicate is true for all elements up to
    /// but not including the index N, and is false for all elements
    /// starting with index N.
    /// Behavior is undefined if there is no such N.
    func binarySearch(predicate: (Iterator.Element) -> Bool) -> Index {
        var low = startIndex
        var high = endIndex
        while low != high {
            let mid = index(low, offsetBy: distance(from: low, to: high)/2)
            if predicate(self[mid]) {
                low = index(after: mid)
            } else {
                high = mid
            }
        }
        return low
    }
}

