//
//  ModelCoordinator.swift
//  TogglGoals
//
//  Created by David Davila on 26/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift


internal class ModelCoordinator: NSObject {

    // MARK: - Exposed binding targets

    internal var apiCredential: BindingTarget<TogglAPICredential?> { return _apiCredential.bindingTarget }
    internal var twoPartReportPeriod: BindingTarget<TwoPartTimeReportPeriod> { return _twoPartReportPeriod.deoptionalizedBindingTarget }


    // MARK: - Target backing properties

    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)
    private let _twoPartReportPeriod = MutableProperty<TwoPartTimeReportPeriod?>(nil)

    // MARK: - Current date

    private let currentDateGenerator: CurrentDateGeneratorProtocol


    // MARK: - URLSession derived from TogglAPICredential

    private lazy var urlSession: MutableProperty<URLSession?> = {
        let p = MutableProperty<URLSession?>(nil)
        p <~ _apiCredential.map(URLSession.init)
        return p
    }()


    // MARK: - Profile

    private let retrieveProfileNetworkAction: RetrieveProfileNetworkAction
    private let retrieveProfileCacheAction: RetrieveProfileCacheAction
    private let storeProfileCacheAction: StoreProfileCacheAction

    private lazy var _profile = MutableProperty<Profile?>(nil)
    internal lazy var profile = Property(_profile)


    // MARK: - Projects

    private let retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction

    private lazy var _projects = MutableProperty(IndexedProjects())
    internal lazy var projects = Property(_projects)

    lazy var fetchProjectIDsByGoalsAction = FetchProjectIDsByGoalsAction { [unowned self] in
        return self.goalsStore.fetchProjectIDsByGoalsAction.applySerially()
    }

    internal lazy var readProjectAction =
        ReadProjectAction { [unowned self] projectId in
            let projectProperty = self.projects.map { $0[projectId] }
            return SignalProducer(value: projectProperty)
    }

    // MARK: - Reports

    private let retrieveReportsNetworkAction: RetrieveReportsNetworkAction

    private let _reports = MutableProperty(IndexedTwoPartTimeReports())
    private lazy var reports = Property(_reports)

    /// Action which takes a project ID as input and returns a producer that sends a single
    /// Property value corresponding to the report associated with the project ID.
    internal lazy var readReportAction = ReadReportAction { [unowned self] projectId in
        let reportProperty = self.reports.map { $0[projectId] }.skipRepeats { $0 == $1 }
        return SignalProducer(value: reportProperty)
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
        currentDateGenerator.updateTrigger <~ t.updateRunningEntry
        return t
    }()


    // Connected outside the scope of property initializers to avoid a dependency cycle
    // between the initializers of apiAccess and runningEntryUpdateTimer
    private func connectRunningEntryUpdateTimer() {
        retrieveRunningEntryNetworkAction <~ runningEntryUpdateTimer.updateRunningEntry.producer
            .combineLatest(with: urlSession)
            .map { _, session in session }
    }


    // MARK: - Goals

    private let goalsStore: ProjectIDsByGoalsProducingGoalsStore

    /// Action which takes a project ID as input and returns a producer that sends a single
    /// Property value corresponding to the goal associated with the project ID.
    internal var readGoalAction: ReadGoalAction {
        return goalsStore.readGoalAction
    }

    /// Action which accepts new (or edited) goal values and stores them
    internal var writeGoalAction: WriteGoalAction { return goalsStore.writeGoalAction }

    /// Action which takes a project ID as input and deletes the goal associated with that project ID
    internal var deleteGoalAction: DeleteGoalAction { return goalsStore.deleteGoalAction }


    // MARK: -

    private let scheduler = QueueScheduler.init(name: "ModelCoordinator-scheduler")

    internal init(currentDateGenerator: CurrentDateGeneratorProtocol,
                  retrieveProfileNetworkAction: RetrieveProfileNetworkAction,
                  retrieveProfileCacheAction: RetrieveProfileCacheAction,
                  storeProfileCacheAction: StoreProfileCacheAction,
                  retrieveProjectsNetworkAction: RetrieveProjectsNetworkAction,
                  retrieveReportsNetworkAction: RetrieveReportsNetworkAction,
                  retrieveRunningEntryNetworkAction: RetrieveRunningEntryNetworkAction,
                  goalsStore: ProjectIDsByGoalsProducingGoalsStore) {
        self.currentDateGenerator = currentDateGenerator
        self.retrieveProfileNetworkAction = retrieveProfileNetworkAction
        self.retrieveProfileCacheAction = retrieveProfileCacheAction
        self.storeProfileCacheAction = storeProfileCacheAction
        self.retrieveProjectsNetworkAction = retrieveProjectsNetworkAction
        self.retrieveReportsNetworkAction = retrieveReportsNetworkAction
        self.retrieveRunningEntryNetworkAction = retrieveRunningEntryNetworkAction
        self.goalsStore = goalsStore
        super.init()

        goalsStore.projectIDs <~ projects.map { [ProjectID]($0.keys) }

        retrieveProfileNetworkAction <~ urlSession.signal.throttle(while: retrieveProfileNetworkAction.isExecuting, on: scheduler)
        _profile <~ Signal.merge(retrieveProfileNetworkAction.values,
                                 retrieveProfileCacheAction.values.skipNil())
        storeProfileCacheAction <~ retrieveProfileNetworkAction.values.throttle(while: storeProfileCacheAction.isExecuting, on: scheduler)

        let workspaceIDs = _profile.producer.skipNil().map { $0.workspaces.map { $0.id } }

        retrieveProjectsNetworkAction <~ SignalProducer.combineLatest(urlSession.producer.skipNil(), workspaceIDs)
            .throttle(while: retrieveProjectsNetworkAction.isExecuting, on: scheduler)
        _projects <~ retrieveProjectsNetworkAction.values

        retrieveReportsNetworkAction <~ SignalProducer.combineLatest(urlSession.producer.skipNil(),
                                                                     workspaceIDs,
                                                                     _twoPartReportPeriod.producer.skipNil())
            .throttle(while: retrieveReportsNetworkAction.isExecuting, on: scheduler)
        _reports <~ retrieveReportsNetworkAction.values

        connectRunningEntryUpdateTimer()
    }
}


// MARK: -

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
