//
//  SelectionDetailViewController.swift
//  TogglTargets
//
//  Created by David Davila on 03.04.17.
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

private let projectDetailsVCContainment = "ProjectDetailsVCContainment"
private let emtpySelectionVCContainment = "EmtpySelectionVCContainment"

class SelectionDetailViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface =
        (projectId: SignalProducer<ProjectID?, Never>,
        currentDate: SignalProducer<Date, Never>,
        calendar: SignalProducer<Calendar, Never>,
        periodPreference: SignalProducer<PeriodPreference, Never>,
        runningEntry: SignalProducer<RunningEntry?, Never>,
        readProject: ReadProject,
        readTimeTarget: ReadTimeTarget,
        writeTimeTarget: BindingTarget<TimeTarget>,
        readReport: ReadReport)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Local use of project

    private let readProject = MutableProperty<((ProjectID) -> SignalProducer<Project?, Never>)?>(nil)
    private let selectedProjectID = MutableProperty<ProjectID?>(nil)
    private lazy var selectedProject: SignalProducer<Project?, Never> = selectedProjectID.producer
        .throttle(while: readProject.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readProject.producer.skipNil())
        .map { projectID, readProject -> SignalProducer<Project?, Never> in
            if let projectID = projectID {
                return readProject(projectID)
            } else {
                return SignalProducer(value: nil)
            }
        }
        .flatten(.latest)

    // MARK: - Contained view controllers

    private lazy var projectDetailsViewController: ProjectDetailsViewController = {
        let details = self.storyboard!.instantiateController(withIdentifier: "ProjectDetailsViewController")
            as! ProjectDetailsViewController // swiftlint:disable:this force_cast

        details <~ SignalProducer.combineLatest(SignalProducer(value: selectedProject.skipNil()),
                                                lastBinding.producer.skipNil())
            .map { selectedProjectProducer, binding in
                (selectedProjectProducer,
                 binding.currentDate,
                 binding.calendar,
                 binding.periodPreference,
                 binding.runningEntry,
                 binding.readTimeTarget,
                 binding.writeTimeTarget,
                 binding.readReport)
        }

        addChild(details)

        return details
    }()

    private lazy var emptySelectionViewController: EmptySelectionViewController = {
        let empty = self.storyboard!.instantiateController(withIdentifier: "EmptySelectionViewController")
            as! EmptySelectionViewController // swiftlint:disable:this force_cast
        addChild(empty)
        return empty
    }()

    @IBOutlet weak var containerView: NSView!

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        selectedProjectID <~ lastBinding.latestOutput { $0.projectId }
        readProject <~ lastBinding.producer.skipNil().map { $0.readProject }

        let debounceScheduler = QueueScheduler()
        reactive.lifetime.observeEnded {
            _ = debounceScheduler
        }

        let selectedViewController = selectedProjectID
            .producer
            .map { $0 != nil }
            .skipRepeats()
            .debounce(0.1, on: debounceScheduler)
            .observe(on: UIScheduler())
            .map { [unowned self] projectSelected in projectSelected ?
                self.projectDetailsViewController : self.emptySelectionViewController }

        containerView.uniqueSubview <~ selectedViewController.map { $0.view }
    }
}
