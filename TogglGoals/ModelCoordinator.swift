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
    private var projects = Dictionary<Int64, Project>() {
        didSet {
            sortProjects()
        }
    }
    
    private func sortProjects() {
        let projectIds = [Int64](projects.keys)
        let sortedProjectIds = projectIds.sorted { id0, id1 in
            let goal0 = goalsStore.goalProperty(for: id0).value,
            goal1 = goalsStore.goalProperty(for: id1).value
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
        
        let indexOfLastProjectWithGoal = sortedProjectIds.binarySearch { (projectId) -> Bool in
            goalsStore.goalProperty(for: projectId).value != nil
        }
        let idsOfProjectsWithGoals = sortedProjectIds.prefix(indexOfLastProjectWithGoal)
        let idsOfProjectsWithoutGoals = sortedProjectIds.suffix(sortedProjectIds.count - indexOfLastProjectWithGoal)

        projectsProperty.value = ProjectsByGoals(projects: projects,
                                                 sortedProjectIds: sortedProjectIds,
                                                 idsOfProjectsWithGoals: idsOfProjectsWithGoals,
                                                 idsOfProjectsWithoutGoals: idsOfProjectsWithoutGoals)
    }
    
    internal let projectsProperty = Property<ProjectsByGoals>(value: nil)
    
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
                self?.projects = projects
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

    internal func project(for id: Int64) -> Project? {
        return projects[id]
    }
    
    internal func goalProperty(for projectId: Int64) -> Property<TimeGoal> {
        return goalsStore.goalProperty(for: projectId)
    }
    
    @discardableResult
    internal func setGoal(_ goal: TimeGoal) -> Property<TimeGoal> {
        let property = goalsStore.storeNew(goal: goal)
        sortProjects()
        return property
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

struct ProjectsByGoals {
    let projects: Dictionary<Int64, Project>
    let sortedProjectIds: [Int64]
    let idsOfProjectsWithGoals: ArraySlice<Int64>
    let idsOfProjectsWithoutGoals: ArraySlice<Int64>
}

extension ProjectsByGoals {
    func project(for indexPath: IndexPath) -> Project? {
        let projectIds: ArraySlice<Int64>
        switch indexPath.section {
        case 0: projectIds = idsOfProjectsWithGoals
        case 1: projectIds = idsOfProjectsWithoutGoals
        default: return nil
        }
        
        let projectId = projectIds[indexPath.item + projectIds.startIndex]
        return projects[projectId]
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

