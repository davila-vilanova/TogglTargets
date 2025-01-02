//
//  ProjectsListActivitySplitViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 28.12.17.
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

class ProjectsListActivityViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        projectIDsByTimeTargets: ProjectIDsByTimeTargetsProducer,
        selectedProjectId: BindingTarget<ProjectID?>,
        selectProjectId: SignalProducer<ProjectID?, Never>,
        runningEntry: SignalProducer<RunningEntry?, Never>,
        currentDate: SignalProducer<Date, Never>,
        periodPreference: SignalProducer<PeriodPreference, Never>,
        modelRetrievalStatus: SignalProducer<ActivityStatus, Never>,
        readProject: ReadProject,
        readTimeTarget: ReadTimeTarget,
        readReport: ReadReport)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    private let displayActivity = MutableProperty(false)

    // MARK: - Contained view controllers

    private var projectsListViewController: ProjectsListViewController?
    lazy private var activityViewController: ActivityViewController = {
        let activity = self.storyboard!.instantiateController(withIdentifier: "ActivityViewController")
            as! ActivityViewController // swiftlint:disable:this force_cast
        addChild(activity)
        stackView.addView(activity.view, in: .bottom)
        activity.view.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
        activity.view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
        return activity
    }()

    @IBOutlet weak var stackView: NSStackView!

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let projects = segue.destinationController as? ProjectsListViewController {
            projectsListViewController = projects

            projects <~ lastBinding.producer.skipNil().map {
                ($0.projectIDsByTimeTargets,
                 $0.selectedProjectId,
                 $0.selectProjectId,
                 $0.runningEntry,
                 $0.currentDate,
                 $0.periodPreference,
                 $0.readProject,
                 $0.readTimeTarget,
                 $0.readReport)
            }
        }
    }

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        activityViewController <~ SignalProducer<ActivityViewController.Interface, Never>(
            value: (modelRetrievalStatus: lastBinding.latestOutput { $0.modelRetrievalStatus },
                    requestDisplay: displayActivity.bindingTarget)
        )

        // Duplicated to allow independent animations
        let showActivity: BindingTarget<Void> = activityViewController.view.reactive
            .makeBindingTarget { [unowned self] activityView, _ in
                NSAnimationContext.runAnimationGroup({ context in
                    context.allowsImplicitAnimation = false
                    activityView.animator().isHidden = false
                    self.stackView.layoutSubtreeIfNeeded()
                }, completionHandler: nil)
        }

        let hideActivity: BindingTarget<Void> = activityViewController.view.reactive
            .makeBindingTarget { [unowned self] activityView, _ in
                NSAnimationContext.runAnimationGroup({ context in
                    context.allowsImplicitAnimation = true
                    activityView.isHidden = true
                    self.stackView.layoutSubtreeIfNeeded()
                }, completionHandler: nil)
        }

        showActivity <~ displayActivity.signal.skipRepeats().filter { $0 }.map { _ in () }
        hideActivity <~ displayActivity.signal.skipRepeats().filter { !$0 }.map { _ in () }
    }
}
