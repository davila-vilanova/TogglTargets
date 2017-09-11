//
//  ModelCoordinator.swift
//  TogglGoals
//
//  Created by David Davila on 26/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

// ModelCoordinator is not thread safe
internal class ModelCoordinator: NSObject {
    private let goalsStore: GoalsStore

    internal var profile = MutableProperty<Profile?>(nil)


    // MARK: - Projects and updates

    internal private(set) var projectsByGoals = ProjectsByGoals() // Could be a mutable property even if list VCs would rather listen to full update and clued update separately

    private var fullProjectsUpdatePipe = Signal<ProjectsByGoals, NoError>.pipe()
    internal var fullProjectsUpdate: Signal<ProjectsByGoals, NoError> {
        return fullProjectsUpdatePipe.output
    }

    private var cluedProjectsUpdatePipe = Signal<CollectionUpdateClue, NoError>.pipe()
    internal var cluedProjectsUpdate: Signal<CollectionUpdateClue, NoError> {
        return cluedProjectsUpdatePipe.output
    }


    // MARK : -

    private var reportProperties = Dictionary<Int64, MutableProperty<TwoPartTimeReport?>>()
    
    internal let runningEntry = MutableProperty<RunningEntry?>(nil)
    internal var runningEntryRefreshTimer: Timer?

    private let apiCredential = TogglAPICredential()

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

    var now: Signal<Date, NoError> { return _now.signal }
    let _now: MutableProperty<Date>
    let calendar: MutableProperty<Calendar>

    private let dateScheduler = QueueScheduler.init(name: "ModelCoordinator date scheduler")
    private var updateNowOnRunningEntryTickDisposable: Disposable?

    internal init(cache: ModelCache, goalsStore: GoalsStore) {
        self.goalsStore = goalsStore

        var calendarValue = Calendar(identifier: .iso8601)
        calendarValue.locale = Locale.current // TODO: get from user profile
        calendar = MutableProperty<Calendar>(calendarValue)

        let currentDate = dateScheduler.currentDate
        _now = MutableProperty(currentDate)

        startOfPeriod = calendar.value.firstDayOfMonth(for: currentDate)
        yesterday = try? calendar.value.previousDay(for: currentDate, notBefore: startOfPeriod)
        today = calendar.value.dayComponents(from: currentDate)

        super.init()

        // Update the now signal as seldom as possible and as precisely as required to match minute increments in the accumulated running time entry
        // TODO: extract and test this logic
        Property.combineLatest(runningEntry, calendar).producer
            .startWithValues { [unowned self] (runningEntry, calendar) in
                // Keep at most one regular update of the now signal related to the current time entry
                if let disposable = self.updateNowOnRunningEntryTickDisposable {
                    disposable.dispose()
                    self.updateNowOnRunningEntryTickDisposable = nil
                }

                guard let runningEntry = runningEntry else {
                    return
                }

                let nextRefresh = calendar.date(byAdding: DateComponents(minute: 1), to: runningEntry.start)! // it is a sound calculation, force result unwrapping
                self.updateNowOnRunningEntryTickDisposable = self.dateScheduler.schedule(after: nextRefresh, interval: .seconds(60), action: {
                    self._now.value = self.dateScheduler.currentDate
                })
        }

        retrieveUserDataFromToggl()
    }

    private func retrieveUserDataFromToggl() {
        let retrieveProfileOp = NetworkRetrieveProfileOperation(credential: apiCredential)
        retrieveProfileOp.onSuccess = { profile in
            self.profile.value = profile
        }

        let retrieveWorkspacesOp = NetworkRetrieveWorkspacesOperation(credential: apiCredential)

        let retrieveProjectsOp = NetworkRetrieveProjectsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential)
        let retrieveReportsOp = NetworkRetrieveReportsSpawningOperation(retrieveWorkspacesOperation: retrieveWorkspacesOp, credential: apiCredential, startOfPeriod: startOfPeriod, yesterday: yesterday, today: today)

        retrieveProjectsOp.outputCollectionOperation.completionBlock = { [unowned self] in
            if let projects = retrieveProjectsOp.outputCollectionOperation.collectedOutput {
                self.projectsByGoals = ProjectsByGoals(projects: projects, goalsStore: self.goalsStore)
                self.fullProjectsUpdatePipe.input.send(value: self.projectsByGoals)
            }
        }

        retrieveReportsOp.outputCollectionOperation.completionBlock = { [unowned self] in
            if let reports = retrieveReportsOp.outputCollectionOperation.collectedOutput {
                for (projectId, report) in reports {
                    self.reportProperty(for: projectId).value = report
                }
            }
        }
        
        networkQueue.addOperation(retrieveProfileOp)
        networkQueue.addOperation(retrieveWorkspacesOp)
        networkQueue.addOperation(retrieveProjectsOp)
        networkQueue.addOperation(retrieveReportsOp)
    }

    // MARK: - Goals
    
    internal func goalProperty(for projectId: Int64) -> MutableProperty<TimeGoal?> {
        let goalProperty = goalsStore.goalProperty(for: projectId)
        goalProperty.skipRepeats{ $0 == $1 }.signal.observeValues { [unowned self] timeGoalOrNil in
            self.goalChanged(for: projectId)
        }
        return goalProperty
    }

    private func goalChanged(for projectId: Int64) {
        let indexPaths = projectsByGoals.moveProjectAfterGoalChange(projectId: projectId)!
        let clue = CollectionUpdateClue(itemMovedFrom: indexPaths.0, to: indexPaths.1)
        cluedProjectsUpdatePipe.input.send(value: clue)
    }

    // MARK: -
    
    internal func reportProperty(for projectId: Int64) -> MutableProperty<TwoPartTimeReport?> {
        if let property = reportProperties[projectId] {
            return property
        } else {
            let property = MutableProperty<TwoPartTimeReport?>(nil)
            reportProperties[projectId] = property
            return property
        }
    }

    internal func startRefreshingRunningTimeEntry() {
        guard runningEntryRefreshTimer == nil || runningEntryRefreshTimer?.isValid == false else {
            return
        }
        runningEntryRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true, block: { [unowned self] (timer) in
            self.retrieveRunningTimeEntry()
        })
        retrieveRunningTimeEntry()
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
