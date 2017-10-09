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
    private let goalsStore: GoalsStore
    private lazy var session = URLSession(togglAPICredential: apiCredential)

    // MARK: - Exposed properties and signals

    internal lazy var profile = Property(_profile)

    internal lazy var projectsByGoals = Property(_projectsByGoals)
    internal var fullProjectsUpdate: Signal<Bool, NoError> {
        return fullProjectsUpdatePipe.output
    }
    internal var cluedProjectsUpdate: Signal<CollectionUpdateClue, NoError> {
        return cluedProjectsUpdatePipe.output
    }

    internal lazy var runningEntry = Property(_runningEntry)
    internal lazy var now = Property(_now)
    internal lazy var calendar = Property(_calendar)


    // MARK: - Backing of exposed properties and signals

    private let _profile = MutableProperty<Profile?>(nil)
    private let _projectsByGoals = MutableProperty(ProjectsByGoals())

    private var fullProjectsUpdatePipe = Signal<Bool, NoError>.pipe()
    private var cluedProjectsUpdatePipe = Signal<CollectionUpdateClue, NoError>.pipe()

    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
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
        let indexPaths = _projectsByGoals.value.moveProjectAfterGoalChange(projectId: projectId)!
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

    private var runningEntryRefreshTimer: Timer?

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
        _runningEntry <~ session.togglAPIRequestProducer(for: RunningEntryService.endpoint, decoder: RunningEntryService.decodeRunningEntry).mapToNoError()
    }


    // MARK : -

    private let apiCredential = TogglAPICredential()

    private var reportProperties = Dictionary<Int64, MutableProperty<TwoPartTimeReport?>>()
    private var reports = MutableProperty([Int64 : TwoPartTimeReport]())

    private lazy var startOfPeriod: DayComponents = _calendar.value.firstDayOfMonth(for: scheduler.currentDate)
    private lazy var yesterday: DayComponents? = try? _calendar.value.previousDay(for: scheduler.currentDate, notBefore: startOfPeriod)
    private lazy var today: DayComponents = _calendar.value.dayComponents(from: scheduler.currentDate)

    private let scheduler = QueueScheduler.init(name: "ModelCoordinator scheduler")

    private var updateNowOnRunningEntryTickDisposable: Disposable?

    internal init(cache: ModelCache, goalsStore: GoalsStore) {
        self.goalsStore = goalsStore

        super.init()

        // Update the now property as seldom as possible and as precisely as required to match minute increments in the accumulated running time entry
        // TODO: extract and test this logic
        Property.combineLatest(_runningEntry, _calendar).producer
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
        _profile <~ session.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)
            .start(on: scheduler)
            .mapToNoError() // TODO: divert errors

        // workspaceIdsProducer will emit one value event per workspace ID
        let workspaceIdsProducer: SignalProducer<Int64, NoError> = profile.producer.skipNil()
            .take(first: 1)
            .map { SignalProducer($0.workspaces) }
            .flatten(.merge)
            .map { $0.id }

        _projectsByGoals <~ workspaceIdsProducer
            .map(ProjectsService.endpoint)
            .map { [session] in session.togglAPIRequestProducer(for: $0, decoder: ProjectsService.decodeProjects) }
            .flatten(.merge)
            .mapToNoError()
            .reduce(into: [Int64 : Project](), { (indexedProjects, projects) in
                for project in projects {
                    indexedProjects[project.id] = project
                }
            })
            .map { [goalsStore = self.goalsStore] (projects) -> ProjectsByGoals in
                ProjectsByGoals(projects: projects, goalsStore: goalsStore)
            }
            .on(value: { [updateObserver = fullProjectsUpdatePipe.input] (_) in updateObserver.send(value: true) })


        func workedTimesProducer(workspaceIdsProducer: SignalProducer<Int64, NoError>,
                                 since: DayComponents,
                                 until: DayComponents) -> SignalProducer<[Int64 : TimeInterval], APIAccessError> {
            return workspaceIdsProducer
                .map { ReportsService.endpoint(workspaceId: $0, since: since.iso8601String, until: until.iso8601String, userAgent: UserAgent) }
                .map { [session] in session.togglAPIRequestProducer(for: $0, decoder: ReportsService.decodeReportEntries) }
                .flatten(.merge)
                .reduce(into: [Int64 : TimeInterval]()) { (indexedWorkedTimeEntries, reportEntries) in
                    for entry in reportEntries {
                        indexedWorkedTimeEntries[entry.id] = TimeInterval.from(milliseconds: entry.time)
                    }
            }
        }

        let previousToTodayWorkedTimesProducer: SignalProducer<[Int64 : TimeInterval], APIAccessError> = {
            if let yesterday = yesterday {
                return workedTimesProducer(workspaceIdsProducer: workspaceIdsProducer, since: startOfPeriod, until: yesterday)
            } else {
                return SignalProducer<[Int64 : TimeInterval], APIAccessError>([[Int64: TimeInterval]()])
            }
        }()

        let todayWorkedTimesProducer = workedTimesProducer(workspaceIdsProducer: workspaceIdsProducer, since: today, until: today)

        reports <~ SignalProducer.combineLatest(previousToTodayWorkedTimesProducer.mapToNoError(),
                                                todayWorkedTimesProducer.mapToNoError())
            .reduce(into: [Int64 : TwoPartTimeReport]()) { [startOfPeriod, today] (indexedTwoPartReports, indexedTimes) in
                let indexedPreviousToTodayTimes = indexedTimes.0
                let indexedTodayTimes = indexedTimes.1

                let ids: Set<Int64> = Set<Int64>(indexedPreviousToTodayTimes.keys).union(indexedTodayTimes.keys)

                for id in ids {
                    let timeWorkedPreviousToToday: TimeInterval = indexedPreviousToTodayTimes[id] ?? 0.0
                    let timeWorkedToday: TimeInterval = indexedTodayTimes[id] ?? 0.0
                    indexedTwoPartReports[id] = TwoPartTimeReport(projectId: id, since: startOfPeriod, until: today, workedTimeUntilYesterday: timeWorkedPreviousToToday, workedTimeToday: timeWorkedToday)
                }
        }

        reports.producer.startWithValues { [unowned self] (indexedReports) in
            for (projectId, report) in indexedReports {
                self.reportMutableProperty(for: projectId).value = report
            }
        }
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
