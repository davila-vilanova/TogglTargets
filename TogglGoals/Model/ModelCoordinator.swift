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

    private lazy var reportsPeriod: SignalProducer<Period, NoError> =
        SignalProducer.combineLatest(_periodPreference.producer.skipNil(), calendar.producer, now.producer)
            .map { $0.currentPeriod(for: $1, now: $2) }


    // MARK: - Data retrieval

    private lazy var apiAccess: TogglAPIAccess = {
        let reportPeriodsProducer = ReportPeriodsProducer()
        reportPeriodsProducer.startDate <~ reportsPeriod.map { $0.start }
        reportPeriodsProducer.endDate <~ reportsPeriod.map { $0.end }
        reportPeriodsProducer.calendar <~ calendar
        reportPeriodsProducer.now <~ now
        let aa = TogglAPIAccess(reportPeriodsProducer: reportPeriodsProducer)
        aa.apiCredential <~ _apiCredential.producer.skipNil()
        return aa
    }()

    private let goalsStore: GoalsStore


    // MARK: - Exposed properties and signals

    // TODO: attempt to simplify by keeping only the producer, or forward to apiAccess's producer producing function
    internal lazy var actionRetrieveProfile = Action { [unowned self] in
        self.apiAccess.makeProfileProducer()
            .take(first: 1)
            .flatten(.latest)
    }
    private lazy var _profile: MutableProperty<Profile?> = {
        let m = MutableProperty<Profile?>(nil)
        m <~ actionRetrieveProfile.values
        return m
    }()
    internal lazy var profile = Property(_profile)
    

    // can stay a property since it's updated periodically and there's a binding target somewhere which can be used to trigger retri(ev)al
    internal lazy var actionRetrieveRunningEntry = Action { [unowned self] in
        self.apiAccess.makeRunningEntryProducer()
            .take(first: 1)
            .flatten(.latest) // TODO: Generify
    }
    private lazy var _runningEntry: MutableProperty<RunningEntry?> = {
        let m = MutableProperty<RunningEntry?>(nil)
        m <~ actionRetrieveRunningEntry.values // TODO: generalize too
        return m
    }()
    internal lazy var runningEntry = Property(_runningEntry)

    internal lazy var actionRetrieveProjects = Action { [unowned self] in
        self.apiAccess.makeProjectsProducer()
            .take(first: 1)
            .flatten(.latest)
    }
    private lazy var _projects: MutableProperty<IndexedProjects> = {
        let m = MutableProperty(IndexedProjects())
        m <~ actionRetrieveProjects.values
        return m
    }()
    internal lazy var projects = Property(_projects)

    internal lazy var actionRetrieveReports = Action { [unowned self] in
        self.apiAccess.makeReportsProducer()
            .take(first: 1)
            .flatten(.latest).logEvents(identifier: "1")
    }
    private lazy var _reports: MutableProperty<IndexedTwoPartTimeReports> = {
        let m = MutableProperty(IndexedTwoPartTimeReports())
        m <~ actionRetrieveReports.values.logEvents(identifier: "2")
        return m
    }()
    internal lazy var reports = Property(_reports)

    // TODO: use producer instead of property
    internal lazy var goals = Property(goalsStore.allGoals)

    internal lazy var now = Property(_now)
    internal lazy var calendar = Property(_calendar)

    internal var apiCredential: BindingTarget<TogglAPICredential?> { return _apiCredential.bindingTarget }

    internal var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }

    // MARK: - Backing of exposed properties and signals

    private lazy var _now = MutableProperty(scheduler.currentDate)
    private lazy var _calendar: MutableProperty<Calendar> = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current // TODO: get from user profile
        return MutableProperty(cal)
    }()
    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)

    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)

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
            let extracted = self.reports.map { $0[projectId] }.skipRepeats { $0 == $1 }
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
        actionRetrieveRunningEntry <~ runningEntryUpdateTimer.updateRunningEntry
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
