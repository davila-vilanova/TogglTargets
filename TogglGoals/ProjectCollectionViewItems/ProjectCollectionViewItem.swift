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
    private let currentDate = MutableProperty<Date?>(nil)

    func connectOnceInLifecycle(runningEntry: SignalProducer<RunningEntry?, NoError>,
                                currentDate: SignalProducer<Date, NoError>) {
        guard Thread.current.isMainThread else {
            assert(false)
            return
        }
        guard areOnceConnectionsPerformed == false else {
            return
        }
        self.runningEntry <~ runningEntry
        self.currentDate <~ currentDate
        areOnceConnectionsPerformed = true
    }
    private var areOnceConnectionsPerformed = false

    // MARK: - Outlets

    @IBOutlet weak var projectNameLabel: NSTextField!
    @IBOutlet weak var goalLabel: NSTextField!
    @IBOutlet weak var reportLabel: NSTextField!


    // MARK: - Inputs

    internal func setInputs(project: SignalProducer<Property<Project?>, NoError>,
                            goal: SignalProducer<Goal?, NoError>,
                            report: SignalProducer<Property<TwoPartTimeReport?>, NoError>) {
        projects <~ project
        goals <~ SignalProducer(value: goal)
        reports <~ report
    }

    // MARK: - Backing properties

    private let projects = MutableProperty<Property<Project?>?>(nil)
    private let goals = MutableProperty<SignalProducer<Goal?, NoError>?>(nil)
    private let reports = MutableProperty<Property<TwoPartTimeReport?>?>(nil)


    // MARK: - Selection of latest binding

    private lazy var project: SignalProducer<Project?, NoError> = projects.producer.skipNil().flatten(.latest)
    private lazy var goal: SignalProducer<Goal?, NoError> = goals.producer.skipNil().flatten(.latest)
    private lazy var report: SignalProducer<TwoPartTimeReport?, NoError> = reports.producer.skipNil().flatten(.latest)


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
                                                                      currentDate.producer.skipNil())
            .map { (project, runningEntryOrNil, currentDate) -> TimeInterval in
                guard let runningEntry = runningEntryOrNil else {
                    return 0.0
                }
                guard runningEntry.projectId == project.id else {
                    return 0.0
                }
                return runningEntry.runningTime(at: currentDate)
        }
        let totalWorkedTime = SignalProducer.combineLatest(workedTimeFromReport, workedTimeFromRunningEntry)
            .map { (t0, t1) in return t0 + t1 }

        let formattedTime = totalWorkedTime.mapToString(timeFormatter: timeFormatter)
        reportLabel.reactive.text <~ formattedTime.map { "\($0) worked" }
    }
}
