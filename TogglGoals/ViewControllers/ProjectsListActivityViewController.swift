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

class ProjectsListActivityViewController: NSViewController, BindingTargetProvider {

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

    private var projectsListViewController: ProjectsListViewController?
    lazy private var activityViewController: ActivityViewController = {
        let activity = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ActivityViewController")) as! ActivityViewController
        addChildViewController(activity)
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
                ($0.projectIDsByGoals,
                 $0.selectedProjectId,
                 $0.runningEntry,
                 $0.currentDate,
                 $0.periodPreference,
                 $0.readProject,
                 $0.readGoal,
                 $0.readReport)
            }
        }
    }

    // MARK: -

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

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
