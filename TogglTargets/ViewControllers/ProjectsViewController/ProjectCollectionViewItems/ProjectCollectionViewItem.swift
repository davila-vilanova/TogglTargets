//
//  ProjectCollectionViewItem.swift
//  TogglTargets
//
//  Created by David Davila on 22/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

fileprivate let NonSelectedBackgroundColor = NSColor.white
fileprivate let NonSelectedTextColor = NSColor.black
fileprivate let FocusedSelectedBackgroundColor = NSColor.init(red: 60.0/255.0, green: 126.0/255.0, blue: 242.0/255.0, alpha: 1)
fileprivate let FocusedSelectedTextColor = NSColor.white
fileprivate let NonFocusedSelectedBackgroundColor = NSColor.darkGray
fileprivate let NonFocusedSelectedTextColor = NSColor.white

class ProjectCollectionViewItem: NSCollectionViewItem, BindingTargetProvider {

    typealias Interface = (
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        project: SignalProducer<Project?, NoError>,
        timeTarget: SignalProducer<TimeTarget?, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        report: SignalProducer<TwoPartTimeReport?, NoError>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Outlets

    @IBOutlet weak var visualEffectView: NSVisualEffectView!
    @IBOutlet weak var projectNameField: NSTextField!
    @IBOutlet weak var goalField: NSTextField!
    @IBOutlet weak var reportField: NSTextField!
    @IBOutlet weak var bottomLining: NSBox!


    // MARK: -

    override var isSelected: Bool {
        set { _isSelected.value = newValue }
        get { return _isSelected.value }
    }
    private let _isSelected = MutableProperty(false)

    @objc var isLastItemInSection: Bool{
        set { _isLastItemInSection.value = newValue }
        get { return _isLastItemInSection.value }
    }
    private let _isLastItemInSection = MutableProperty(false)

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
        let timeTarget = lastBinding.latestOutput { $0.timeTarget }
        let periodPreference = lastBinding.latestOutput { $0.periodPreference }
        let report = lastBinding.latestOutput { $0.report }

        projectNameField.reactive.text <~ project.map { project -> String in
            return project?.name ?? ""
        }

        let targetPeriodFormat = SignalProducer.merge(
            periodPreference.filter(isMonthly).map { _ in
                NSLocalizedString("project-list.item.target.time.monthly", comment: "target amount of time per month as it appears in each of the project list items")
            },
            periodPreference.filter(isWeekly).map { _ in
                NSLocalizedString("project-list.item.target.time.weekly", comment: "target amount of time per week as it appears in each of the project list items")
        })

        goalField.reactive.text <~ timeTarget.skipNil().map{ $0.hoursTarget }
            .map { TimeInterval.from(hours: $0) }
            .mapToString(timeFormatter: timeFormatter)
            .combineLatest(with: targetPeriodFormat)
            .map { String.localizedStringWithFormat($1, $0) }
        goalField.reactive.text <~ timeTarget.filter { $0 == nil }
            .map { _ in () }
            .map { NSLocalizedString("project-list.item.target.no-time-target", comment: "message to show in each of the project list items when there is no associated time target") }

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

        bottomLining.reactive.makeBindingTarget { (lining, state) in
            let (isSelected, isLastItemInSection) = state
            lining.isHidden = isSelected || isLastItemInSection
        } <~ SignalProducer.combineLatest(_isSelected, _isLastItemInSection)

        let materialTarget = visualEffectView.reactive.makeBindingTarget {
            $0.material = $1
        }
        let defaultMaterial = visualEffectView.material
        materialTarget <~ _isSelected.producer.map { $0 ? NSVisualEffectView.Material.selection : defaultMaterial }
    }
}
