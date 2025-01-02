//
//  ProjectDetailsViewController.swift
//  TogglTargets
//
//  Created by David Davila on 21/10/2016.
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

class ProjectDetailsViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        project: SignalProducer<Project, Never>,
        currentDate: SignalProducer<Date, Never>,
        calendar: SignalProducer<Calendar, Never>,
        periodPreference: SignalProducer<PeriodPreference, Never>,
        runningEntry: SignalProducer<RunningEntry?, Never>,
        readTimeTarget: ReadTimeTarget,
        writeTimeTarget: BindingTarget<TimeTarget>,
        readReport: ReadReport)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Private properties

    /// Selected project.
    private let project = MutableProperty<Project?>(nil)

    private let readTimeTarget = MutableProperty<ReadTimeTarget?>(nil)
    private let readReport = MutableProperty<ReadReport?>(nil)

    // MARK: - Derived input

    private lazy var projectId: SignalProducer<Int64, Never> = project.producer.skipNil().map { $0.id }

    /// TimeTarget corresponding to the selected project.
    private lazy var timeTargetForCurrentProject: SignalProducer<TimeTarget?, Never> = projectId
        .throttle(while: readTimeTarget.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readTimeTarget.producer.skipNil())
        .map { projectId, readTimeTarget in readTimeTarget(projectId) }
        .flatten(.latest)

    /// Report corresponding to the selected project.
    private lazy var reportForCurrentProject: SignalProducer<TwoPartTimeReport?, Never> = projectId
        .throttle(while: readReport.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readReport.producer.skipNil())
        .map { projectId, readTimeTarget in readTimeTarget(projectId) }
        .flatten(.latest) // TODO: generalize and reuse

    // MARK: - Contained view controllers

    private lazy var timeReportViewController: TimeReportViewController = {
        let timeReport = self.storyboard!.instantiateController(withIdentifier: "TimeReportViewController")
            as! TimeReportViewController // swiftlint:disable:this force_cast
        timeReport <~ SignalProducer(
            value: (projectId: projectId,
                    timeTarget: timeTargetForCurrentProject.skipNil(),
                    report: reportForCurrentProject,
                    runningEntry: lastBinding.latestOutput { $0.runningEntry },
                    calendar: lastBinding.latestOutput { $0.calendar },
                    currentDate: lastBinding.latestOutput { $0.currentDate },
                    periodPreference: lastBinding.latestOutput { $0.periodPreference }))
        addChild(timeReport)
        return timeReport
    }()

    private lazy var noTimeTargetViewController: NoTimeTargetViewController = {
        let noTarget = self.storyboard!.instantiateController(withIdentifier: "NoTimeTargetViewController")
            as! NoTimeTargetViewController // swiftlint:disable:this force_cast
        addChild(noTarget)
        return noTarget
    }()

    private func setupConditionalVisibilityOfContainedViews() {
        let selectedTimeTargetController = timeTargetForCurrentProject
            .observe(on: UIScheduler())
            .map { [unowned self] in
            $0 == nil ? self.noTimeTargetViewController : self.timeReportViewController
        }
        timeReportView.uniqueSubview <~ selectedTimeTargetController.map { $0.view }.skipRepeats()
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let timeTargetController = segue.destinationController as? TimeTargetViewController {
            let validBindings = lastBinding.producer.skipNil()
            timeTargetController <~
                SignalProducer.combineLatest(
                    validBindings.map { ($0.calendar, $0.periodPreference, $0.writeTimeTarget) },
                    SignalProducer(value: timeTargetForCurrentProject.producer))
                    .map {
                        (calendar: $0.0,
                         timeTarget: $1,
                         periodPreference: $0.1,
                         userUpdates: $0.2)
            }
        }
    }

    // MARK: - Outlets

    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var timeReportView: NSView!

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        project <~ lastBinding.latestOutput { $0.project }

        let lastValidBinding = lastBinding.producer.skipNil()
        readTimeTarget <~ lastValidBinding.map { $0.readTimeTarget }
        readReport <~ lastValidBinding.map { $0.readReport }

        setupLocalProjectDisplay()
        setupConditionalVisibilityOfContainedViews()
    }

    private func setupLocalProjectDisplay() {
        project.producer.observe(on: UIScheduler()).startWithValues { [unowned self] projectOrNil in
            self.projectName.stringValue = projectOrNil?.name ?? ""
        }
    }
}
