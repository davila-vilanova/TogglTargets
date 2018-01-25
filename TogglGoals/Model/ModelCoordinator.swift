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

typealias ReadProjectAction = Action<ProjectID, Property<Project?>, NoError>
typealias ReadReportAction = Action<ProjectID, Property<TwoPartTimeReport?>, NoError>


/// Combines data from the Toggl API and the user's goals.
/// Determines the dates of the reports to retrieve based on the user's period
/// preference and the current date.
/// Keeps the running entry up to date and triggers updates to the current date
/// generator.
internal class ModelCoordinator: NSObject {

    /// MARK: - Internal dependencies

    /// The `TogglAPIDataRetriever` used to access data from the Toggl API.
    private let togglDataRetriever: TogglAPIDataRetriever

    /// The store for the user's goals.
    private let goalsStore: ProjectIDsByGoalsProducingGoalsStore

    /// The current date generator used to access and trigger updates to the
    /// current date.
    private let currentDateGenerator: CurrentDateGeneratorProtocol

    /// The `ReportPeriodsProducer` used to determine the dates to scope the
    /// requests for reports.
    private let reportPeriodsProducer: ReportPeriodsProducer


    // MARK: - Dependency inputs

    /// The API credential used to access the Toggl API. Some resources, such as
    /// the reports endpoint, require a token-based credential (`TogglAPITokenCredential`).
    var apiCredential: BindingTarget<TogglAPICredential?> { return togglDataRetriever.apiCredential }

    /// Binding target for `PeriodPreference` representing the user preference
    /// corresponding to how to determine the current period for scoping the
    /// requested time reports.
    internal var periodPreference: BindingTarget<PeriodPreference> { return reportPeriodsProducer.periodPreference }

    /// Binding target for the current `Calendar` used to perform calendrical
    /// computations.
    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    private var _calendar = MutableProperty<Calendar?>(nil)


    // MARK: - Profile

    /// The value of the last retrieved user profile.
    var profile: Property<Profile?> { return togglDataRetriever.profile }


    // MARK: - Projects

    /// Combines the project IDs from the Toggl API and the user's goals.
    lazy var fetchProjectIDsByGoalsAction = FetchProjectIDsByGoalsAction { [unowned self] in
        return self.goalsStore.fetchProjectIDsByGoalsAction.applySerially()
    }

    /// Accesses one particular `Project` by its project ID, returns a property
    /// whose value can be tracked over time.
    internal lazy var readProjectAction =
        ReadProjectAction { [unowned self] projectId in
            let projectProperty = self.togglDataRetriever.projects.map { $0?[projectId] }
            return SignalProducer(value: projectProperty)
    }


    // MARK: - Reports

    /// Accesses one particular `TwoPartTimeReport` by its project ID, returns a
    /// property whose value can be tracked over time.
    internal lazy var readReportAction = ReadReportAction { [unowned self] projectId in
        let reportProperty = self.togglDataRetriever.reports.map { $0?[projectId] }.skipRepeats { $0 == $1 }
        return SignalProducer(value: reportProperty)
    }


    // MARK: - RunningEntry

    /// The value of the last retrieved running entry. Periodically updated.
    var runningEntry: Property<RunningEntry?> { return togglDataRetriever.runningEntry }

    /// Apply this action to attempt a refresh and update of the currently
    /// running entry.
    var updateRunningEntry: RefreshAction { return togglDataRetriever.updateRunningEntry }

    /// Used to schedule the next automatic refresh of the currently running entry.
    private lazy var runningEntryUpdateTimer: RunningEntryUpdateTimer = RunningEntryUpdateTimer()


    // MARK: - Goals

    /// Accesses one particular `Goal` by its project ID, returns a property
    /// whose value can be tracked over time.
    internal var readGoalAction: ReadGoalAction {
        return goalsStore.readGoalAction
    }

    /// Action which accepts new (or edited) goal values and stores them.
    internal var writeGoalAction: WriteGoalAction { return goalsStore.writeGoalAction }

    /// Action which takes a project ID as input and deletes the goal associated
    /// with that project ID.
    internal var deleteGoalAction: DeleteGoalAction { return goalsStore.deleteGoalAction }


    // MARK: - Forcing a refresh of all data

    /// Triggers an attempt to refresh the user profile, projects and reports.
    internal var refreshAllData: RefreshAction { return togglDataRetriever.refreshAllData }


    // MARK: - Activity and Errors

    var retrievalStatus: SignalProducer<ActivityStatus, NoError> { return togglDataRetriever.status }


    // MARK: -

    /// Initializes a new instance with the provided dependencies.
    ///
    /// - parameters:
    ///   - togglDataRetriever: The `TogglAPIDataRetriever` used to access data
    ///     from the Toggl API.
    ///   - goalsStore: The store for the user's goals.
    ///   - currentDateGenerator: The current date generator used to access and
    ///     trigger updates to the current date.
    ///   - reportPeriodsProducer: The `ReportPeriodsProducer` used to determine
    ///     the dates to scope the requests for reports.
    internal init(togglDataRetriever: TogglAPIDataRetriever,
                  goalsStore: ProjectIDsByGoalsProducingGoalsStore,
                  currentDateGenerator: CurrentDateGeneratorProtocol,
                  reportPeriodsProducer: ReportPeriodsProducer) {
        self.togglDataRetriever = togglDataRetriever
        self.goalsStore = goalsStore
        self.currentDateGenerator = currentDateGenerator
        self.reportPeriodsProducer = reportPeriodsProducer

        super.init()

        self.goalsStore.projectIDs <~ self.togglDataRetriever.projects.producer.skipNil().map { [ProjectID]($0.keys) }
        reportPeriodsProducer.calendar <~ _calendar.producer.skipNil()
        reportPeriodsProducer.currentDate <~ currentDateGenerator.producer
        togglDataRetriever.twoPartReportPeriod <~ reportPeriodsProducer.twoPartPeriod.skipRepeats()
        currentDateGenerator.updateTrigger <~ retrievalStatus.map { _ in () }.throttle(1.0, on: QueueScheduler())

        runningEntryUpdateTimer.lastEntryStart <~ runningEntry.map { $0?.start }
        updateRunningEntry <~ runningEntryUpdateTimer.trigger

        let runningEntryStopped = runningEntry.producer
            .skipRepeats { $0 == $1 }
            .combinePrevious()
            .filter { $0.0 != nil } // If it was `nil` it was not 'stopped'.
            .map { _ in () }

        togglDataRetriever.refreshReports <~ runningEntryStopped
    }
}


// MARK: -

/// Emits empty values that act as triggers to update the currently running entry
/// based on whether a running entry is currently running and its start date.
fileprivate class RunningEntryUpdateTimer {

    /// Binding target to receive the start date of the currently running entry,
    /// or `nil` if there is no time entry currently running.
    lazy var lastEntryStart: BindingTarget<Date?> = BindingTarget(on: scheduler, lifetime: lifetime) { [unowned self] (runningEntryStartDate: Date?) in
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

    /// Emits empty values that act as triggers to update the currently running entry
    var trigger: Signal<(), NoError> { return updateRunningEntryPipe.output }

    /// The pipe used to convey values to `updateRunningEntry`
    private let updateRunningEntryPipe = Signal<(), NoError>.pipe()

    /// The `QueueScheduler` used to schedule actions in the future.
    private let scheduler = QueueScheduler(name: "RunningEntryUpdateTimer-scheduler")

    /// Keeps the `Disposable` corresponding to the latest scheduled action.
    private var scheduledTickDisposable: Disposable?

    /// The lifetime associated with `runningEntryStart` and its token.
    private let (lifetime, token) = Lifetime.make()
}

fileprivate extension QueueScheduler {
    /// Finds the closest future date that is a minute increment over the input date.
    ///
    /// - note: the input date must be a date in the past.
    ///
    /// - parameters:
    ///   - inputDate: The `Date` used as reference to calculate the future `Date`.
    ///   - byMultipleOf: The `TimeInterval` to use as discrete step over the
    ///     input `Date` to calculate the return `Date`
    /// - returns: A `Date` representing the closest future date that is a future
    ///   of `inputDate` by a multiple of `byMultipleOf`, or or nil if `inputDate`
    ///   is itself in the future.
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
