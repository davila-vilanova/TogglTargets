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

class ProjectCollectionViewItem: NSCollectionViewItem, BindingTargetProvider {

    typealias Interface = (
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        project: SignalProducer<Project?, NoError>,
        goal: SignalProducer<Goal?, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        report: SignalProducer<TwoPartTimeReport?, NoError>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Outlets

    @IBOutlet weak var projectNameLabel: NSTextField!
    @IBOutlet weak var goalLabel: NSTextField!
    @IBOutlet weak var reportLabel: NSTextField!


    // MARK: - NSCollectionViewItem

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

        let runningEntry = lastBinding.latestOutput { $0.runningEntry }
        let currentDate = lastBinding.latestOutput { $0.currentDate }
        let project = lastBinding.latestOutput { $0.project }
        let goal = lastBinding.latestOutput { $0.goal }
        let periodPreference = lastBinding.latestOutput { $0.periodPreference }
        let report = lastBinding.latestOutput { $0.report }

        projectNameLabel.reactive.text <~ project.map { project -> String in
            return project?.name ?? "(nothing)"
        }

        let targetPeriodDescription = SignalProducer.merge(periodPreference.filter(isMonthly).map { _ in "hours per month" },
                                                           periodPreference.filter(isWeekly).map { _ in "hours per week" })

        goalLabel.reactive.text <~ goal.skipNil().combineLatest(with: targetPeriodDescription)
            .map { "\($0.hoursTarget) \($1)" }

        goalLabel.reactive.makeBindingTarget { $0.animator().isHidden = $1 } <~ goal.map { $0 == nil }

        let workedTimeFromReport = report.map { (reportValueOrNil) -> TimeInterval in
            return reportValueOrNil?.workedTime ?? 0.0
        }
        let workedTimeFromRunningEntry = SignalProducer.combineLatest(project, runningEntry, currentDate)
            .map { (project, runningEntryOrNil, currentDate) -> TimeInterval in
                guard let runningEntry = runningEntryOrNil else {
                    return 0.0
                }
                guard runningEntry.projectId == project?.id else {
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
