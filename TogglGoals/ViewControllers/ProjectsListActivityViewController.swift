//
//  ProjectsListActivitySplitViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 28.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

fileprivate let ProjectsListVCContainment = "ProjectsListVCContainment"
fileprivate let ActivityVCContainment = "ActivityVCContainment"

class ProjectsListActivityViewController: NSViewController, ViewControllerContaining, BindingTargetProvider {

    // Interface

    internal typealias Interface = (
        projectIDsByGoals: ProjectIDsByGoalsProducer,
        selectedProjectId: BindingTarget<ProjectID?>,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>,
        readProject: ReadProject,
        readGoal: ReadGoal,
        readReport: ReadReport)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    private let displayActivity = MutableProperty(false)

    // MARK: - Contained view controllers

    private var projectsListViewController: ProjectsListViewController!
    private var activityViewController: ActivityViewController!

    @IBOutlet weak var stackView: NSStackView!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let projectsListVC = controller as? ProjectsListViewController {
            self.projectsListViewController = projectsListVC
            stackView.addView(projectsListVC.view, in: .top)
        } else if let activityVC = controller as? ActivityViewController {
            self.activityViewController = activityVC
            stackView.addView(activityVC.view, in: .bottom)
            activityVC.view.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
            activityVC.view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
        }
    }

    // MARK: -

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [ProjectsListVCContainment, ActivityVCContainment])

        projectsListViewController <~ lastBinding.producer.skipNil().map {
            ($0.projectIDsByGoals,
             $0.selectedProjectId,
             $0.runningEntry,
             $0.currentDate,
             $0.periodPreference,
             $0.readProject,
             $0.readGoal,
             $0.readReport)
        }

        activityViewController <~ SignalProducer<ActivityViewController.Interface, NoError>(
            value: (lastBinding.latestOutput { $0.modelRetrievalStatus },
                    displayActivity.bindingTarget)
        )

        // Duplicated to allow independent animations
        let showActivity: BindingTarget<Void> = activityViewController.view.reactive.makeBindingTarget { [unowned self] activityView, _ in
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = false
                activityView.animator().isHidden = false
                self.stackView.layoutSubtreeIfNeeded()
            }, completionHandler: nil)
        }

        let hideActivity: BindingTarget<Void> = activityViewController.view.reactive.makeBindingTarget { [unowned self] activityView, _ in
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true
                activityView.isHidden = true
                self.stackView.layoutSubtreeIfNeeded()
            }, completionHandler: nil)
        }

        showActivity <~ displayActivity.producer.skipRepeats().filter{ $0 }.map { _ in () }
        hideActivity <~ displayActivity.producer.skipRepeats().filter{ !$0 }.map { _ in () }
    }
}
