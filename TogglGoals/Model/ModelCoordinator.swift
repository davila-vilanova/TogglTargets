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

typealias PropertyProvidingAction<Value> = Action<Int64, Property<Value?>, NoError>
typealias BindingTargetProvidingAction<Value> = Action<Int64, BindingTarget<Value?>, NoError>

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

    private lazy var apiAccess: TogglAPIAccess = {
        let aa = TogglAPIAccess()
        aa.apiCredential <~ _apiCredential.producer.skipNil()
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

    internal lazy var projects = Property(apiAccess.projects)
    internal lazy var goals = Property(goalsStore.allGoals)

    internal lazy var now = Property(_now)
    internal lazy var calendar = Property(_calendar)

    internal var apiCredential: BindingTarget<TogglAPICredential?> { return _apiCredential.bindingTarget }


    // MARK: - Backing of exposed properties and signals

    private lazy var _now = MutableProperty(scheduler.currentDate)
    private lazy var _calendar: MutableProperty<Calendar> = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current // TODO: get from user profile
        return MutableProperty(cal)
    }()
    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)


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
        return goalsStore.goalProperty(for: projectId)
    }

    private func goalBindingTarget(for projectId: Int64) -> BindingTarget<Goal?> {
        return goalsStore.goalBindingTarget(for: projectId)
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

    private lazy var runningEntryUpdateTimer: RunningEntryUpdateTimer = {
        let t = RunningEntryUpdateTimer()
        t.runningEntryStart <~ runningEntry.map { $0?.start }
        updateNow <~ t.updateRunningEntry
        return t
    }()

    // Connected outside the scope of property initializers to avoid a dependency cycle
    // between the initializers of apiAccess and runningEntryUpdateTimer
    private func connectRunningEntryUpdateTimer() {
        apiAccess.retrieveRunningEntry <~ runningEntryUpdateTimer.updateRunningEntry
    }

    internal func forceRefreshRunningEntry() {
        apiAccess.retrieveRunningEntry <~ SignalProducer<(), NoError>(value: ())
    }

    // MARK: - Current time (now) update

    private lazy var updateNow = BindingTarget<()>(on: scheduler, lifetime: lifetime) { [_now, scheduler] in
        _now <~ SignalProducer(value: scheduler.currentDate)
    }

    // MARK: -

    private let scheduler = QueueScheduler.init(name: "ModelCoordinator-scheduler")
    private let (lifetime, token) = Lifetime.make()

    internal init(cache: ModelCache, goalsStore: GoalsStore) {
        self.goalsStore = goalsStore
        super.init()

        connectRunningEntryUpdateTimer()
    }
}

fileprivate class RunningEntryUpdateTimer {
    // input
    lazy var runningEntryStart: BindingTarget<Date?> = BindingTarget(on: scheduler, lifetime: lifetime) { [unowned self] (runningEntryStartDate: Date?) in
        let oneMinute = TimeInterval.from(minutes: 1)
        let oneMinuteDispatch = DispatchTimeInterval.seconds(Int(oneMinute))

        let scheduleDate: Date = {
            guard let startDate = runningEntryStartDate,
                let date = self.scheduler.closestFutureDateIncrementing(date: startDate, byMultipleOf: oneMinute) else {
                    return self.scheduler.currentDate.addingTimeInterval(oneMinute)
            }
            return date
        }()
        if let disposable = self.scheduledTickDisposable {
            disposable.dispose()
        }
        self.scheduledTickDisposable = self.scheduler.schedule(after: scheduleDate,
                                                               interval: oneMinuteDispatch,
                                                               action: { [update = self.updateRunningEntryPipe.input] in
            update.send(value: ())
        })
    }

    // output
    var updateRunningEntry: Signal<(), NoError> { return updateRunningEntryPipe.output }

    private let updateRunningEntryPipe = Signal<(), NoError>.pipe()

    private let scheduler = QueueScheduler(name: "RunningEntryUpdateTimer-scheduler")
    private var scheduledTickDisposable: Disposable?
    private let (lifetime, token) = Lifetime.make()
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
