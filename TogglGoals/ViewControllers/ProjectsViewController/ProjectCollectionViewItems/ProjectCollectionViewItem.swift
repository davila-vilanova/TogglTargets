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

    @IBOutlet weak var projectNameField: NSTextField!
    @IBOutlet weak var goalField: NSTextField!
    @IBOutlet weak var reportField: NSTextField!
    @IBOutlet weak var bottomLining: NSBox!


    // MARK: - NSCollectionViewItem

    override var isSelected: Bool {
        set {
            let selected = newValue
            super.isSelected = selected

            let color = selected ? NSColor.controlHighlightColor : NSColor.clear
            self.view.layer?.backgroundColor = color.cgColor
            refreshBottomLiningVisibility()
        }

        get {
            return super.isSelected
        }
    }


    // MARK: -

    var isLastItemInSection: Bool = false {
        didSet {
            refreshBottomLiningVisibility()
        }
    }

    private func refreshBottomLiningVisibility() {
        bottomLining.isHidden = isSelected || isLastItemInSection
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

        projectNameField.reactive.text <~ project.map { project -> String in
            return project?.name ?? ""
        }

        let targetPeriodFormat = SignalProducer.merge(
            periodPreference.filter(isMonthly).map { _ in
                NSLocalizedString("project-list.item.goal.target.monthly", comment: "target amount of time per month as it appears in each of the project list items")
            },
            periodPreference.filter(isWeekly).map { _ in
                NSLocalizedString("project-list.item.goal.target.weekly", comment: "target amount of time per week as it appears in each of the project list items")
        })

        goalField.reactive.text <~ goal.skipNil().map{ $0.hoursTarget }
            .map { TimeInterval.from(hours: $0) }
            .mapToString(timeFormatter: timeFormatter)
            .combineLatest(with: targetPeriodFormat)
            .map { String.localizedStringWithFormat($1, $0) }

        goalField.reactive.makeBindingTarget { $0.animator().isHidden = $1 } <~ goal.map { $0 == nil }

        let noReport = report.filter { $0 == nil }.map { _ in () }
        let workedTimeFromReport = report.skipNil().map { $0.workedTime }
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
        reportField.reactive.text <~ SignalProducer.merge(noReport.map { NSLocalizedString("project-list.item.report.no-data", comment: "message to show in each of the project list items when there is no report data") },
                                                          formattedTime.map { String.localizedStringWithFormat(NSLocalizedString("project-list.item.report.worked-time", comment: "formatted worked time for the project represented by a project list item"), $0) })
    }
}
