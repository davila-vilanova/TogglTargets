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

    // MARK: - Exposed binding targets

    internal var apiCredential: BindingTarget<TogglAPICredential?> { return _apiCredential.bindingTarget }
    internal var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }

    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)
    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)


    // MARK: - Current time and calendar

    internal lazy var now = Property(_now)
    internal lazy var calendar = Property(_calendar)

    private lazy var _now = MutableProperty(scheduler.currentDate)
    private lazy var _calendar: MutableProperty<Calendar> = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale.current // TODO: get from user profile
        return MutableProperty(cal)
    }()


    // MARK: Working dates

    private lazy var reportsPeriod: SignalProducer<Period, NoError> =
        SignalProducer.combineLatest(_periodPreference.producer.skipNil(), calendar.producer, now.producer)
            .map { $0.currentPeriod(for: $1, now: $2) }

    private lazy var reportPeriodsProducer: ReportPeriodsProducer = {
        let p = ReportPeriodsProducer()
        p.reportPeriod <~ reportsPeriod
        p.calendar <~ calendar
        p.now <~ now
        return p
    }()


    // MARK: - URLSession derived from TogglAPICredential

    private lazy var urlSession: MutableProperty<URLSession?> = {
        let p = MutableProperty<URLSession?>(nil)
        p <~ _apiCredential.map(URLSession.init)
        return p
    }()


    // MARK: - Profile

    /*private*/ let retrieveProfileNetworkAction: RetrieveProfileNetworkAction
    private var currentRetrieveProfileNetworkDisposable: Disposable?
    private var keepAroundActionInputFeedDisposable: Disposable?
    private var keepAroundIsEnabledDisposable: Disposable?
    private let retrieveProfileCacheAction: RetrieveProfileCacheAction
    private let storeProfileCacheAction: StoreProfileCacheAction

    private lazy var _profile = MutableProperty<Profile?>(nil)
    internal lazy var profile = Property(_profile)


    // MARK: - Projects

    private let retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction

    private lazy var _projects = MutableProperty(IndexedProjects())
    internal lazy var projects = Property(_projects)


    // MARK: - Reports

    private let retrieveReportsNetworkAction: RetrieveReportsNetworkAction

    private lazy var _reports = MutableProperty(IndexedTwoPartTimeReports())
    internal lazy var reports = Property(_reports)

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


    // MARK: - RunningEntry

    private let retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction

    private lazy var _runningEntry: MutableProperty<RunningEntry?> = {
        let m = MutableProperty<RunningEntry?>(nil)
        m <~ retrieveRunningEntryNetworkAction.values
        return m
    }()
    internal lazy var runningEntry = Property(_runningEntry)

    private lazy var runningEntryUpdateTimer: RunningEntryUpdateTimer = {
        let t = RunningEntryUpdateTimer()
        t.runningEntryStart <~ runningEntry.map { $0?.start }
        updateNow <~ t.updateRunningEntry
        return t
    }()


    // Connected outside the scope of property initializers to avoid a dependency cycle
    // between the initializers of apiAccess and runningEntryUpdateTimer
    private func connectRunningEntryUpdateTimer() {
        retrieveRunningEntryNetworkAction <~ runningEntryUpdateTimer.updateRunningEntry.producer
            .combineLatest(with: urlSession)
            .map { _, session in session }
    }

    private lazy var updateNow = BindingTarget<()>(on: scheduler, lifetime: lifetime) { [_now, scheduler] in
        _now <~ SignalProducer(value: scheduler.currentDate)
    }


    // MARK: - Goals

    private let goalsStore: GoalsStore

    // TODO: use producer instead of property
    internal lazy var goals = Property(goalsStore.allGoals)

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


    // MARK: -

    private let scheduler = QueueScheduler.init(name: "ModelCoordinator-scheduler")
    private let (lifetime, token) = Lifetime.make()

    internal init(retrieveProfileNetworkAction: RetrieveProfileNetworkAction,
                  retrieveProfileCacheAction: RetrieveProfileCacheAction,
                  storeProfileCacheAction: StoreProfileCacheAction,
                  retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction,
                  retrieveReportsNetworkAction: RetrieveReportsNetworkAction,
                  retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction,
                  goalsStore: GoalsStore) {

        self.retrieveProfileNetworkAction = retrieveProfileNetworkAction
        self.retrieveProfileCacheAction = retrieveProfileCacheAction
        self.storeProfileCacheAction = storeProfileCacheAction
        self.retrieveProjectsNetworkAction = retrieveProjectsNetworkAction
        self.retrieveReportsNetworkAction = retrieveReportsNetworkAction
        self.retrieveRunningEntryNetworkAction = retrieveRunningEntryNetworkAction
        self.goalsStore = goalsStore
        super.init()

//        keepAroundIsEnabledDisposable = retrieveProfileNetworkAction.isEnabled.producer.startWithValues { print("isEnabled=\($0)") }

        keepAroundActionInputFeedDisposable = urlSession.producer.startWithValues { [unowned self] session in
            if let disposable = self.currentRetrieveProfileNetworkDisposable {
                print("will dispose - action.isEnabled=\(self.retrieveProfileNetworkAction.isEnabled.value)")
                disposable.dispose()
                self.currentRetrieveProfileNetworkDisposable = nil
                print("did dispose - action.isEnabled=\(retrieveProfileNetworkAction)")
            }
            print("will apply - action.isEnabled=\(self.retrieveReportsNetworkAction.isEnabled.value)")
            self.currentRetrieveProfileNetworkDisposable = self.retrieveProfileNetworkAction.apply(session).logEvents(identifier: "profile producer").start()
        }
//        retrieveProfileNetworkAction <~ urlSession
        _profile <~ Signal.merge(retrieveProfileNetworkAction.values,
                                 retrieveProfileCacheAction.values.skipNil())
        storeProfileCacheAction <~ retrieveProfileNetworkAction.values

        let workspaceIDs = _profile.producer.skipNil().map { $0.workspaces.map { $0.id } }

        retrieveProjectsNetworkAction <~ SignalProducer.combineLatest(urlSession.producer.skipNil(), workspaceIDs)
        _projects <~ retrieveProjectsNetworkAction.values

        retrieveReportsNetworkAction <~ SignalProducer.combineLatest(urlSession.producer.skipNil(),
                                                                     workspaceIDs,
                                                                     reportPeriodsProducer.twoPartPeriod)
        _reports <~ retrieveReportsNetworkAction.values

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
