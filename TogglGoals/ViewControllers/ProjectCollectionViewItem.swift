//
//  ProjectCollectionViewItem.swift
//  TogglGoals
//
//  Created by David Davila on 22/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

class ProjectCollectionViewItem: NSCollectionViewItem {

    // MARK: Connections to be established once in lifetime

    private let runningEntry = MutableProperty<RunningEntry?>(nil)
    private let now = MutableProperty<Date?>(nil)

    func connectOnceInLifecycle(runningEntry: SignalProducer<RunningEntry?, NoError>,
                                now: SignalProducer<Date, NoError>) {
        guard Thread.current.isMainThread else {
            assert(false)
            return
        }
        guard areOnceConnectionsPerformed == false else {
            return
        }
        self.runningEntry <~ runningEntry
        self.now <~ now
        areOnceConnectionsPerformed = true
    }
    private var areOnceConnectionsPerformed = false

    // MARK: - Outlets

    @IBOutlet weak var projectNameLabel: NSTextField!
    @IBOutlet weak var goalLabel: NSTextField!
    @IBOutlet weak var reportLabel: NSTextField!


    // MARK: - Exposed targets

    internal var projects: BindingTarget<Property<Project?>?> { return _projects.bindingTarget }
    internal var goals: BindingTarget<Property<Goal?>?> { return _goals.bindingTarget }
    internal var reports: BindingTarget<Property<TwoPartTimeReport?>?> { return _reports.bindingTarget }

    // MARK: - Backing properties

    private let _projects = MutableProperty<Property<Project?>?>(nil)
    private let _goals = MutableProperty<Property<Goal?>?>(nil)
    private let _reports = MutableProperty<Property<TwoPartTimeReport?>?>(nil)


    // MARK: - Selection of latest binding

    private lazy var project: SignalProducer<Project?, NoError> = _projects.producer.skipNil().flatten(.latest)
    private lazy var goal: SignalProducer<Goal?, NoError> = _goals.producer.skipNil().flatten(.latest)
    private lazy var report: SignalProducer<TwoPartTimeReport?, NoError> = _reports.producer.skipNil().flatten(.latest)


    // MARK: - NSCollectionViewItem

    override var textField: NSTextField? {
        get {
            return projectNameLabel
        }
        set { }
    }

    override var isSelected: Bool {
        set {
            let selected = newValue
            super.isSelected = selected

            let color = selected ? NSColor.controlHighlightColor : NSColor.clear
            self.view.layer?.backgroundColor = color.cgColor
        }

        get {
            return super.isSelected
        }
    }

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        projectNameLabel.reactive.text <~ project.map { project -> String in
            return project?.name ?? "(nothing)"
        }

        goalLabel.reactive.text <~ goal.map { goal -> String in
            if let goal = goal {
                return "\(goal.hoursPerMonth) hours per month"
            } else {
                return "(no goal)"
            }
        }
        let workedTimeFromReport = report.map { (reportValueOrNil) -> TimeInterval in
            return reportValueOrNil?.workedTime ?? 0.0
        }
        let workedTimeFromRunningEntry = SignalProducer.combineLatest(project.producer.skipNil(),
                                                                      runningEntry.producer,
                                                                      now.producer.skipNil())
            .map { (project, runningEntryOrNil, now) -> TimeInterval in
                guard let runningEntry = runningEntryOrNil else {
                    return 0.0
                }
                guard runningEntry.projectId == project.id else {
                    return 0.0
                }
                return runningEntry.runningTime(at: now)
        }
        let totalWorkedTime = SignalProducer.combineLatest(workedTimeFromReport, workedTimeFromRunningEntry)
            .map { (t0, t1) in return t0 + t1 }

        let formattedTime = totalWorkedTime.mapToString(timeFormatter: timeFormatter)
        reportLabel.reactive.text <~ formattedTime.map { "\($0) worked" }
    }
}
