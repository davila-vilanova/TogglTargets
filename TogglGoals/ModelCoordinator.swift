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

    private var mutableProjectsByGoals: MutableProperty<ProjectsByGoals>
    internal var projectsByGoals: Property<ProjectsByGoals>

    private var fullProjectsUpdatePipe = Signal<Bool, NoError>.pipe()
    internal var fullProjectsUpdate: Signal<Bool, NoError> {
        return fullProjectsUpdatePipe.output
    }

    private var cluedProjectsUpdatePipe = Signal<CollectionUpdateClue, NoError>.pipe()
    internal var cluedProjectsUpdate: Signal<CollectionUpdateClue, NoError> {
        return cluedProjectsUpdatePipe.output
    }


    // MARK : -

    private var reportProperties = Dictionary<Int64, MutableProperty<TwoPartTimeReport?>>()

    internal let runningEntry: Property<RunningEntry?>
    private let mutableRunningEntry: MutableProperty<RunningEntry?>
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

    internal var now: SignalProducer<Date, NoError> { return _now.producer }
    private let _now: MutableProperty<Date>
    internal let calendar: Property<Calendar>
    private let mutableCalendar: MutableProperty<Calendar>

    private let scheduler = QueueScheduler.init(name: "ModelCoordinator scheduler")
    private var updateNowOnRunningEntryTickDisposable: Disposable?

    internal init(cache: ModelCache, goalsStore: GoalsStore) {
        self.goalsStore = goalsStore

        let mutableProjectsByGoals = MutableProperty<ProjectsByGoals>(ProjectsByGoals())
        self.mutableProjectsByGoals = mutableProjectsByGoals
        self.projectsByGoals = Property<ProjectsByGoals>(mutableProjectsByGoals)

        let mutableRunningEntry = MutableProperty<RunningEntry?>(nil)
        self.mutableRunningEntry = mutableRunningEntry
        self.runningEntry = Property<RunningEntry?>(mutableRunningEntry)

        var calendarValue = Calendar(identifier: .iso8601)
        calendarValue.locale = Locale.current // TODO: get from user profile
        let mutableCalendar = MutableProperty<Calendar>(calendarValue)
        self.mutableCalendar = mutableCalendar
        self.calendar = Property<Calendar>(mutableCalendar)

        let currentDate = scheduler.currentDate
        _now = MutableProperty(currentDate)

        startOfPeriod = mutableCalendar.value.firstDayOfMonth(for: currentDate)
        yesterday = try? mutableCalendar.value.previousDay(for: currentDate, notBefore: startOfPeriod)
        today = mutableCalendar.value.dayComponents(from: currentDate)

        super.init()

        // Update the now property as seldom as possible and as precisely as required to match minute increments in the accumulated running time entry
        // TODO: extract and test this logic
        Property.combineLatest(mutableRunningEntry, mutableCalendar).producer
            .startWithValues { [unowned self] (runningEntry, calendar) in
                // Keep at most one regular update of the now property related to the current time entry
                if let disposable = self.updateNowOnRunningEntryTickDisposable {
                    disposable.dispose()
                    self.updateNowOnRunningEntryTickDisposable = nil
                }

                guard let runningEntry = runningEntry else {
                    return
                }

                let nextRefresh = calendar.date(byAdding: DateComponents(minute: 1), to: runningEntry.start)! // it is a sound calculation, force result unwrapping
                self.updateNowOnRunningEntryTickDisposable = self.scheduler.schedule(after: nextRefresh, interval: .seconds(60), action: {
                    self._now.value = self.scheduler.currentDate
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
                self.mutableProjectsByGoals.value = ProjectsByGoals(projects: projects, goalsStore: self.goalsStore)
                self.fullProjectsUpdatePipe.input.send(value: true)
            }
        }

        retrieveReportsOp.outputCollectionOperation.completionBlock = { [unowned self] in
            if let reports = retrieveReportsOp.outputCollectionOperation.collectedOutput {
                for (projectId, report) in reports {
                    self.reportMutableProperty(for: projectId).value = report
                }
            }
        }
        
        networkQueue.addOperation(retrieveProfileOp)
        networkQueue.addOperation(retrieveWorkspacesOp)
        networkQueue.addOperation(retrieveProjectsOp)
        networkQueue.addOperation(retrieveReportsOp)
    }

    // MARK: - Goals

    /// Each invocation of this Producer will deliver a single value and then complete.
    /// The value is an Action which takes a project ID as input and returns a Property
    /// that conveys the values of the goal associated with the provided project ID.
    internal lazy var goalReadProviderProducer = SignalProducer<Action<Int64, Property<Goal?>, NoError>, NoError> { [unowned self] observer, lifetime in
        let action = Action<Int64, Property<Goal?>, NoError>() { projectId in
            let goalProperty = self.goalProperty(for: projectId)
            return SignalProducer<Property<Goal?>, NoError>(value: goalProperty)
        }
        observer.send(value: action)
        observer.sendCompleted()
    }


    /// Each invocation of this Producer will deliver a single value and then complete.
    /// The value is an Action which takes a project ID as input and returns a BindingTarget
    /// that accepts new (or edited) values for the goal associated with the provided project ID.
    internal lazy var goalWriteProviderProducer = SignalProducer<Action<Int64, BindingTarget<Goal?>, NoError>, NoError> { [unowned self] observer, lifetime in
        let action = Action<Int64, BindingTarget<Goal?>, NoError> { projectId in
            let goalBindingTarget = self.goalBindingTarget(for: projectId)
            return SignalProducer<BindingTarget<Goal?>, NoError>(value: goalBindingTarget)
        }
        observer.send(value: action)
        observer.sendCompleted()
    }


    private func goalProperty(for projectId: Int64) -> Property<Goal?> {
        let goalProperty = goalsStore.goalProperty(for: projectId)
        goalProperty.skipRepeats{ $0 == $1 }.signal.observeValues { [unowned self] timeGoalOrNil in
            self.goalChanged(for: projectId)
        }
        return goalProperty
    }

    private func goalBindingTarget(for projectId: Int64) -> BindingTarget<Goal?> {
        return goalsStore.goalBindingTarget(for: projectId)
    }

    private func goalChanged(for projectId: Int64) {
        let indexPaths = mutableProjectsByGoals.value.moveProjectAfterGoalChange(projectId: projectId)!
        let clue = CollectionUpdateClue(itemMovedFrom: indexPaths.0, to: indexPaths.1)
        cluedProjectsUpdatePipe.input.send(value: clue)
    }

    // MARK: - Reports

    /// Each invocation of this Producer will deliver a single value and then complete.
    /// The value is an Action which takes a project ID as input and returns a Property
    /// that conveys the values of the time report associated with the provided project ID.
    internal lazy var reportReadProviderProducer = SignalProducer<Action<Int64, Property<TwoPartTimeReport?>, NoError>, NoError> { [unowned self] observer, lifetime in
        let action = Action<Int64, Property<TwoPartTimeReport?>, NoError>() { projectId in
            let mutable = self.reportMutableProperty(for: projectId)
            let immutable = Property<TwoPartTimeReport?>(mutable)
            return SignalProducer<Property<TwoPartTimeReport?>, NoError>(value: immutable)
        }
        observer.send(value: action)
        observer.sendCompleted()
    }

    private func reportMutableProperty(for projectId: Int64) -> MutableProperty<TwoPartTimeReport?> {
        if let existing = reportProperties[projectId] {
            return existing
        } else {
            let new = MutableProperty<TwoPartTimeReport?>(nil)
            reportProperties[projectId] = new
            return new
        }
    }

    // MARK: - Running Entry

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
            self.mutableRunningEntry.value = runningEntry
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
