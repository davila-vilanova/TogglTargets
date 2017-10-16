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

internal class ModelCoordinator: NSObject {

    // MARK: Working dates

    private lazy var reportsStartDate: SignalProducer<DayComponents, NoError> =
        SignalProducer.combineLatest(calendar.producer, now.producer).map { (calendar, now) in
            calendar.firstDayOfMonth(for: now)
    }
    private lazy var reportsEndDate: SignalProducer<DayComponents, NoError> =
        SignalProducer.combineLatest(calendar.producer, now.producer).map { (calendar, now) in
            calendar.lastDayOfMonth(for: now)
    }


    // MARK: - Data retrieval

    private let apiCredential = MutableProperty(TogglAPICredential())
    private lazy var apiAccess: TogglAPIAccess = {
        let aa = TogglAPIAccess()
        aa.apiCredential <~ apiCredential
        aa.reportsStartDate <~ reportsStartDate
        aa.reportsEndDate <~ reportsEndDate
        aa.calendar <~ calendar
        aa.now <~ now
        return aa
    }()

    private let goalsStore: GoalsStore


    // MARK: - Exposed properties and signals

    internal var profile: Property<Profile?> { return apiAccess.profile }
    internal var runningEntry: Property<RunningEntry?> { return apiAccess.runningEntry }

    internal lazy var projectsByGoals = Property(_projectsByGoals)

    internal lazy var now = Property(_now)
    internal lazy var calendar = Property(_calendar)


    // MARK: - Backing of exposed properties and signals

    private lazy var _projectsByGoals: MutableProperty<ProjectsByGoals> = {
        let p = MutableProperty(ProjectsByGoals())
        p <~ apiAccess.projects
            .map { [unowned goalsStore] (projects) in
            ProjectsByGoals(projects: projects, goalsStore: goalsStore)
        }
        return p
    }()

    private lazy var _now = MutableProperty(scheduler.currentDate)
    private lazy var _calendar: MutableProperty<Calendar> = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current // TODO: get from user profile
        return MutableProperty(cal)
    }()


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
        _ = _projectsByGoals.value.moveProjectAfterGoalChange(projectId: projectId)!
    }


    // MARK: - Reports

    /// Each invocation of this Producer will deliver a single value and then complete.
    /// The value is an Action which takes a project ID as input and returns a Property
    /// that conveys the values of the time report associated with the provided project ID.
    internal lazy var reportReadProviderProducer = SignalProducer<Action<Int64, Property<TwoPartTimeReport?>, NoError>, NoError> { [unowned self] observer, lifetime in
        let action = Action<Int64, Property<TwoPartTimeReport?>, NoError>() { projectId in
            let extracted = self.apiAccess.reports.map { $0[projectId] }.skipRepeats { $0 == $1 }
            return SignalProducer<Property<TwoPartTimeReport?>, NoError>(value: extracted)
        }
        observer.send(value: action)
        observer.sendCompleted()
    }


    // MARK: - Running entry update

    private let neverDateSignal = Signal<Date?, NoError>.never
    private lazy var runningEntryUpdateTimerInput = MutableProperty(SignalProducer(neverDateSignal))
    private lazy var runningEntryUpdateTimer: RunningEntryUpdateTimer = {
        let t = RunningEntryUpdateTimer()
        t.runningEntryStart <~ runningEntryUpdateTimerInput.producer.flatten(.latest)
        apiAccess.retrieveRunningEntry <~ t.updateRunningEntry
        return t
    }()

    internal func startRefreshingRunningTimeEntry() {
        runningEntryUpdateTimerInput <~ apiAccess.runningEntry.map { SignalProducer(value: $0?.start) }
    }

    internal func stopRefreshingRunningTimeEntry() {
        runningEntryUpdateTimerInput <~ SignalProducer(value: SignalProducer(neverDateSignal))
    }

    // MARK : -

    private let scheduler = QueueScheduler.init(name: "ModelCoordinator-scheduler")

    internal init(cache: ModelCache, goalsStore: GoalsStore) {
        self.goalsStore = goalsStore
        super.init()
    }
}

fileprivate class RunningEntryUpdateTimer {
    // input
    var runningEntryStart: BindingTarget<Date?> { return _runningEntryStart.bindingTarget }
    // output
    var updateRunningEntry: Signal<(), NoError> { return updateRunningEntryPipe.output }

    private let _runningEntryStart = MutableProperty<Date?>(nil)
    private let updateRunningEntryPipe = Signal<(), NoError>.pipe()

    private let scheduler = QueueScheduler(name: "RunningEntryUpdateTimer-scheduler")
    private var scheduledTickDisposable: Disposable?

    init() {
        _runningEntryStart.producer.startWithValues { [unowned self] (startDateOrNil) in
            self.onRunningEntryStartDateValue(startDateOrNil)
        }
    }

    private func onRunningEntryStartDateValue(_ runningEntryStartDate: Date?) {
        let oneMinute = TimeInterval.from(minutes: 1)
        let oneMinuteDispatch = DispatchTimeInterval.seconds(Int(oneMinute))

        let scheduleDate: Date = {
            guard let startDate = runningEntryStartDate,
                let date = scheduler.closestFutureDateIncrementing(date: startDate, byMultipleOf: oneMinute) else {
                return scheduler.currentDate.addingTimeInterval(oneMinute)
            }
            return date
        }()
        if let disposable = scheduledTickDisposable {
            disposable.dispose()
        }
        scheduledTickDisposable = scheduler.schedule(after: scheduleDate, interval: oneMinuteDispatch, action: { [update = updateRunningEntryPipe.input] in
                update.send(value: ())
        })
    }
}

fileprivate extension QueueScheduler {
    // find the closest future date that is a minute increment over the input date
    func closestFutureDateIncrementing(date inputDate: Date, byMultipleOf unit: TimeInterval) -> Date? {
        let now = currentDate
        guard now > inputDate else {
            return nil
        }
        let diff = now.timeIntervalSinceReferenceDate - inputDate.timeIntervalSinceReferenceDate
        let elapsedFullUnitPeriods = floor(diff / unit)
        let closestFutureInterval = inputDate.timeIntervalSinceReferenceDate + (unit * (elapsedFullUnitPeriods + 1))
        return Date(timeIntervalSinceReferenceDate: closestFutureInterval)
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
