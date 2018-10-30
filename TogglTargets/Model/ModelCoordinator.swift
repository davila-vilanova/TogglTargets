//
//  ModelCoordinator.swift
//  TogglTargets
//
//  Created by David Davila on 26/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift


/// Combines data from the Toggl API, the user's goals and the system's time and date.
/// Determines the dates of the reports to retrieve based on the user's period
/// preference and the current date.
/// Keeps the running entry up to date and triggers updates to the current date generator.
internal class ModelCoordinator: NSObject {

    /// MARK: - Internal dependencies

    /// The `TogglAPIDataRetriever` used to access data from the Toggl API.
    private let togglDataRetriever: TogglAPIDataRetriever

    /// The store for the user's goals.
    private let goalsStore: ProjectIDsProducingTimeTargetsStore

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


    // MARK: - Profile

    /// The value of the last retrieved user profile.
    var profile: Property<Profile?> { return togglDataRetriever.profile }


    // MARK: - Projects

    /// Combines the project IDs from the Toggl API and the user's goals.
    var projectIDsByGoals: ProjectIDsByGoalsProducer {
        return self.goalsStore.projectIDsByGoalsProducer
    }

    /// Function which takes a project ID as input and returns a producer that
    /// emits values over time corresponding to the project associated with that
    /// project ID.
    internal lazy var readProject: ReadProject = { projectID in
        self.togglDataRetriever.projects.producer.map { $0?[projectID] }.skipRepeats { $0 == $1 }
    }


    // MARK: - Reports

    /// Function which takes a project ID as input and returns a producer that
    /// emits values over time corresponding to the report associated with that
    /// project ID.
    internal lazy var readReport: ReadReport = { projectID in
        let reports = self.togglDataRetriever.reports.producer

        let noReportData = SignalProducer<TwoPartTimeReport?, NoError>(value: nil)
            .sample(on: reports.filter { $0 == nil }.map { _ in () })
        let retrievedReports = reports.skipNil().map { $0[projectID] }
        let retrievedPresentReports = retrievedReports.skipNil()
        let retrievedAbsentReports =
            SignalProducer.combineLatest(SignalProducer(value: projectID),
                                         self.reportPeriodsProducer.twoPartPeriod.map { $0.scope }
                                            .sample(on: retrievedReports.filter { $0 == nil }.map { _ in () }))
                .map (makeZeroReport)
        let reportData = SignalProducer.merge(retrievedPresentReports, retrievedAbsentReports).map { Optional($0) }

        return SignalProducer.merge(noReportData, reportData)
    }


    // MARK: - RunningEntry

    /// The value of the last retrieved running entry. Periodically updated.
    var runningEntry: Property<RunningEntry?> { return togglDataRetriever.runningEntry }

    /// Apply this action to attempt a refresh and update of the currently
    /// running entry.
    var updateRunningEntry: RefreshAction { return togglDataRetriever.updateRunningEntry }

    /// Used to schedule the next automatic refresh of the currently running entry.
    private let runningEntryUpdateTimer: RunningEntryUpdateTimer


    // MARK: - Updating time

    private let currentDateUpdateTimer: CurrentDateUpdateTimer


    // MARK: - Goals

    /// Function which takes a project ID as input and returns a producer that
    /// emits values over time corresponding to the time target associated with that
    /// project ID.
    ///
    /// - note: `nil` timeTarget values represent a target that does not exist yet or
    ///         that has been deleted.
    internal var readTimeTarget: ReadTimeTarget {
        return goalsStore.readTimeTarget
    }

    /// Target which accepts new (or edited) time target values.
    internal var writeGoal: BindingTarget<TimeTarget> { return goalsStore.writeGoal }

    /// Target which for each received project ID deletes the time target associated with that project ID.
    internal var deleteGoal: BindingTarget<ProjectID> { return goalsStore.deleteGoal }


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
                  goalsStore: ProjectIDsProducingTimeTargetsStore,
                  currentDateGenerator: CurrentDateGeneratorProtocol,
                  calendar: SignalProducer<Calendar, NoError>,
                  reportPeriodsProducer: ReportPeriodsProducer) {
        self.togglDataRetriever = togglDataRetriever
        self.goalsStore = goalsStore
        self.currentDateGenerator = currentDateGenerator
        self.reportPeriodsProducer = reportPeriodsProducer
        self.runningEntryUpdateTimer = RunningEntryUpdateTimer(now: currentDateGenerator.producer,
                                                               lastEntryStart: togglDataRetriever.runningEntry.producer.map { $0?.start},
                                                               calendar: calendar)

        self.currentDateUpdateTimer = CurrentDateUpdateTimer(now: currentDateGenerator.currentDate.producer,
                                                             runningEntry: togglDataRetriever.runningEntry.producer,
                                                             calendar: calendar)

        super.init()

        self.goalsStore.projectIDs <~ self.togglDataRetriever.projects.producer.skipNil().map { [ProjectID]($0.keys) }
        reportPeriodsProducer.calendar <~ calendar
        reportPeriodsProducer.currentDate <~ currentDateGenerator.producer
        togglDataRetriever.twoPartReportPeriod <~ reportPeriodsProducer.twoPartPeriod.skipRepeats()
        updateRunningEntry <~ runningEntryUpdateTimer.trigger
        currentDateGenerator.updateTrigger <~ currentDateUpdateTimer.trigger

        let runningEntryStopped = runningEntry.producer
            .skipRepeats { $0 == $1 }
            .combinePrevious()
            .filter { $0.0 != nil } // If it was `nil` it was not 'stopped'.
            .map { _ in () }

        togglDataRetriever.refreshReports <~ runningEntryStopped
    }
}


// MARK: -

fileprivate let oneMinute = TimeInterval.from(minutes: 1)
fileprivate let oneMinuteDispatch = DispatchTimeInterval.seconds(Int(oneMinute))

/// Emits empty values that act as triggers to update the currently running entry
/// based on whether a running entry is currently running and its start date.
fileprivate class RunningEntryUpdateTimer {
    /// Emits empty values that act as triggers to update the currently running entry
    var trigger: Signal<(), NoError> { return triggerPipe.output }

    /// The pipe used to convey values to `trigger`
    private let triggerPipe = Signal<(), NoError>.pipe()

    /// The `QueueScheduler` used to schedule actions in the future.
    private let scheduler = QueueScheduler(name: "RunningEntryUpdateTimer-scheduler")

    /// Keeps the `Disposable` corresponding to the latest scheduled action.
    private var scheduledTickDisposable: Disposable?

    /// The associated lifetime and its token.
    private let (lifetime, token) = Lifetime.make()

    init(now: SignalProducer<Date, NoError>, lastEntryStart: SignalProducer<Date?, NoError>, calendar: SignalProducer<Calendar, NoError>) {
        let dates = SignalProducer.combineLatest(calendar,
                                                 lastEntryStart.skipRepeats().withLatest(from: now))
            .map { (calendar, dates) -> Date in
                let (runningEntryStart, now) = dates
                let secondsOffset: Int
                if let start = runningEntryStart {
                    secondsOffset = calendar.component(.second, from: start)
                } else {
                    secondsOffset = 0
                }
                return findClosestDate(after: now, matching: secondsOffset, using: calendar)
        }


        lifetime += dates.startWithValues { [unowned self] in
            self.scheduledTickDisposable?.dispose()
            self.scheduledTickDisposable =
                self.scheduler.schedule(after: $0, interval: oneMinuteDispatch, action: { [update = self.triggerPipe.input] in update.send(value: ()) })
        }
    }
}

fileprivate class CurrentDateUpdateTimer {
    /// Emits empty values that act as triggers to update the current date
    var trigger: Signal<(), NoError> { return triggerPipe.output }

    /// The pipe used to convey values to `trigger`
    private let triggerPipe = Signal<(), NoError>.pipe()

    /// The `QueueScheduler` used to schedule actions in the future.
    private let scheduler = QueueScheduler(name: "CurrentDateUpdateTimer-scheduler")

    private var scheduledMinuteOnTheClockTickDisposable: Disposable?

    /// The associated lifetime and its token.
    private let (lifetime, token) = Lifetime.make()

    init(now: SignalProducer<Date, NoError>, runningEntry: SignalProducer<RunningEntry?, NoError>, calendar: SignalProducer<Calendar, NoError>) {
        let trigger = { [unowned self] in self.triggerPipe.input.send(value: ()) }

        // Trigger updates each minute on the clock
        lifetime += SignalProducer.zip(now, calendar).take(first: 1)
            .map { findClosestDate(after: $0, matching: 0, using: $1) }
            .startWithValues { [unowned self] in
            self.scheduledMinuteOnTheClockTickDisposable?.dispose()
            self.scheduledMinuteOnTheClockTickDisposable = self.scheduler.schedule(after: $0, interval: oneMinuteDispatch, action: trigger)
        }

        // Trigger updates each time a new running entry becomes available
        lifetime += runningEntry.skipRepeats().startWithValues { _ in trigger() }
    }
}

fileprivate func findClosestDate(after date: Date, matching secondsComponent: Int, using calendar: Calendar) -> Date {
    let seconds = calendar.component(.second, from: date)
    let offset = (seconds < secondsComponent ? 0 : 60) + secondsComponent - seconds
    return Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate + TimeInterval(offset))
}
