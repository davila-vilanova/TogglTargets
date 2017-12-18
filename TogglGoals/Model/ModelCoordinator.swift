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

/// Combines data from the Toggl API and the user's goals
/// Determines the dates of the periods to retrieve based on the user's period preference current date
/// Keeps the running entry up to date and triggers updates to the current date generator
internal class ModelCoordinator: NSObject {

    private let currentDateGenerator: CurrentDateGeneratorProtocol
    private let togglDataRetriever: TogglAPIDataRetriever
    private let goalsStore: ProjectIDsByGoalsProducingGoalsStore

    // TODO: move reportPeriodsProducer inside MC?
    var twoPartReportPeriod: BindingTarget<TwoPartTimeReportPeriod> { return togglDataRetriever.twoPartReportPeriod }
    var apiCredential: BindingTarget<TogglAPICredential?> { return togglDataRetriever.apiCredential }

    var profile: Property<Profile?> { return togglDataRetriever.profile }

    var apiAccessErrors: Signal<APIAccessError, NoError> { return togglDataRetriever.errors }


    // MARK: - Projects

    /// Combines the project IDs from the toggl API and the user's goals
    lazy var fetchProjectIDsByGoalsAction = FetchProjectIDsByGoalsAction { [unowned self] in
        return self.goalsStore.fetchProjectIDsByGoalsAction.applySerially()
    }

    /// Accesses one particular project, returns a property whose value can be tracked over time
    internal lazy var readProjectAction =
        ReadProjectAction { [unowned self] projectId in
            let projectProperty = self.togglDataRetriever.projects.map { $0[projectId] }
            return SignalProducer(value: projectProperty)
    }

    // MARK: - Reports

    /// Action which takes a project ID as input and returns a producer that sends a single
    /// Property value corresponding to the report associated with the project ID.
    internal lazy var readReportAction = ReadReportAction { [unowned self] projectId in
        let reportProperty = self.togglDataRetriever.reports.map { $0[projectId] }.skipRepeats { $0 == $1 }
        return SignalProducer(value: reportProperty)
    }


    // MARK: - RunningEntry

    var runningEntry: Property<RunningEntry?> { return togglDataRetriever.runningEntry }
    var updateRunningEntry: RefreshAction { return togglDataRetriever.updateRunningEntry }

    private lazy var runningEntryUpdateTimer: RunningEntryUpdateTimer = {
        let t = RunningEntryUpdateTimer()
        t.runningEntryStart <~ runningEntry.map { $0?.start }
        currentDateGenerator.updateTrigger <~ t.updateRunningEntry
        updateRunningEntry <~ t.updateRunningEntry.producer.map { _ in () }
        return t
    }()


    // MARK: - Goals

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


    internal init(togglDataRetriever: TogglAPIDataRetriever,
                  goalsStore: ProjectIDsByGoalsProducingGoalsStore,
                  currentDateGenerator: CurrentDateGeneratorProtocol) {
        self.togglDataRetriever = togglDataRetriever
        self.goalsStore = goalsStore
        self.currentDateGenerator = currentDateGenerator

        super.init()

        self.goalsStore.projectIDs <~ self.togglDataRetriever.projects.map { [ProjectID]($0.keys) }
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
