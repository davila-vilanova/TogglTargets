//
//  ProjectCollectionViewItem.swift
//  TogglTargets
//
//  Created by David Davila on 22/10/2016.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class ProjectCollectionViewItem: NSCollectionViewItem, BindingTargetProvider {

    // MARK: - Interface

    typealias Interface = (
        runningEntry: SignalProducer<RunningEntry?, Never>,
        currentDate: SignalProducer<Date, Never>,
        project: SignalProducer<Project?, Never>,
        timeTarget: SignalProducer<TimeTarget?, Never>,
        periodPreference: SignalProducer<PeriodPreference, Never>,
        report: SignalProducer<TwoPartTimeReport?, Never>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Private properties

    private lazy var runningEntry = lastBinding.latestOutput { $0.runningEntry }
    private lazy var currentDate = lastBinding.latestOutput { $0.currentDate }
    private lazy var project = lastBinding.latestOutput { $0.project }
    private lazy var timeTarget = lastBinding.latestOutput { $0.timeTarget }
    private lazy var periodPreference = lastBinding.latestOutput { $0.periodPreference }
    private lazy var report = lastBinding.latestOutput { $0.report }

    // MARK: - Outlets

    @IBOutlet weak var visualEffectView: NSVisualEffectView!
    @IBOutlet weak var projectNameField: NSTextField!
    @IBOutlet weak var timeTargetField: NSTextField!
    @IBOutlet weak var reportField: NSTextField!
    @IBOutlet weak var bottomLining: NSBox!

    // MARK: -

    override var isSelected: Bool {
        set { _isSelected.value = newValue }
        get { return _isSelected.value }
    }
    private let _isSelected = MutableProperty(false)

    @objc var isLastItemInSection: Bool {
        set { _isLastItemInSection.value = newValue }
        get { return _isLastItemInSection.value }
    }
    private let _isLastItemInSection = MutableProperty(false)

    private lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.unitsStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        wireProjectNameField()
        wireTimeTargetField()
        wireReportField()
        wireBottomLiningVisibility()
        wireSelectionMaterial()
    }

    private func wireProjectNameField() {
        projectNameField.reactive.text <~ project.map { project -> String in
            return project?.name ?? ""
        }
    }

    private func wireTimeTargetField() {
        let targetPeriodFormat = SignalProducer.merge(
            periodPreference.filter(isMonthly).map { _ in
                NSLocalizedString(
                    "project-list.item.target.time.monthly",
                    comment: "target amount of time per month as it appears in each of the project list items")
            },
            periodPreference.filter(isWeekly).map { _ in
                NSLocalizedString(
                    "project-list.item.target.time.weekly",
                    comment: "target amount of time per week as it appears in each of the project list items")
        })

        timeTargetField.reactive.text <~ timeTarget.skipNil().map { $0.hoursTarget }
            .map { TimeInterval.from(hours: $0) }
            .mapToString(timeFormatter: timeFormatter)
            .combineLatest(with: targetPeriodFormat)
            .map { String.localizedStringWithFormat($1, $0) }
        timeTargetField.reactive.text <~ timeTarget.filter { $0 == nil }
            .map { _ in () }
            .map { NSLocalizedString(
                "project-list.item.target.no-time-target",
                comment: "message to show in each of the project list items when there is no associated time target")
        }
    }

    private func wireReportField() {
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
            .map({ (time0: WorkedTime, time1: WorkedTime) in return time0 + time1 })

        let formattedTime = totalWorkedTime.mapToString(timeFormatter: timeFormatter)
        reportField.reactive.text <~ SignalProducer.merge(
            noReport.map { NSLocalizedString(
                "project-list.item.report.no-data",
                comment: "message to show in each of the project list items when there is no report data")
            },
            formattedTime.map { String.localizedStringWithFormat(
                NSLocalizedString("project-list.item.report.worked-time",
                                  comment: "formatted worked time for the project represented by a project list item"),
                $0)
        })
    }

    private func wireBottomLiningVisibility() {
        bottomLining.reactive.makeBindingTarget { (lining, state) in
            let (isSelected, isLastItemInSection) = state
            lining.isHidden = isSelected || isLastItemInSection
            } <~ SignalProducer.combineLatest(_isSelected, _isLastItemInSection)
    }

    private func wireSelectionMaterial() {
        let materialTarget = visualEffectView.reactive.makeBindingTarget {
            $0.material = $1
        }
        let defaultMaterial = visualEffectView.material
        materialTarget <~ _isSelected.producer.map { $0 ? NSVisualEffectView.Material.selection : defaultMaterial }
    }
}
