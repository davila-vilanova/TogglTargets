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

fileprivate let animationDuration = 1.0
class ProjectsListActivityViewController: NSViewController, ViewControllerContaining {

    internal func connectInputs(projectIDsByGoals: ProjectIDsByGoalsProducer,
                                runningEntry: SignalProducer<RunningEntry?, NoError>,
                                currentDate: SignalProducer<Date, NoError>,
                                modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>) {
        enforceOnce(for: "ProjectsListActivitySplitViewController.connectInputs()") {
            self.areViewAndContainedViewControllersAvailable.firstTrue.start(on: UIScheduler()).startWithValues { [unowned self] in
                self.projectsListViewController.connectInputs(projectIDsByGoals: projectIDsByGoals,
                                                              runningEntry: runningEntry,
                                                              currentDate: currentDate)
                self.activityViewController
                    .connectInputs(modelRetrievalStatus: modelRetrievalStatus,
                                   animationSettings: self.animationSettings.producer)
            }
        }
    }

    internal func setActions(readProject: @escaping (ProjectID) -> SignalProducer<Project?, NoError>,
                             readGoal: @escaping (ProjectID) -> SignalProducer<Goal?, NoError>,
                             readReport: @escaping (ProjectID) -> SignalProducer<TwoPartTimeReport?, NoError>) {
        enforceOnce(for: "ProjectsListActivitySplitViewController.setActions()") {
            self.areViewAndContainedViewControllersAvailable.firstTrue.startWithValues { [unowned self] in
                self.projectsListViewController.setActions(readProject: readProject,
                                                           readGoal: readGoal,
                                                           readReport: readReport)
            }
        }
    }

    internal lazy var selectedProjectID = _selectedProjectID.producer
    private let _selectedProjectID = MutableProperty<ProjectID?>(nil)

    // MARK: - Contained view controllers

    private var projectsListViewController: ProjectsListViewController!
    private var activityViewController: ActivityViewController!

    private let areViewAndContainedViewControllersAvailable = MutableProperty(false)

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

    private let animationSettings = MutableProperty<AnimationSettings?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [ProjectsListVCContainment, ActivityVCContainment])

        areViewAndContainedViewControllersAvailable.value = true

        animationSettings.value = AnimationSettings(duration: animationDuration, layoutRootIdentifier: stackView.identifier!)

        _selectedProjectID <~ projectsListViewController.selectedProjectID

        let showActivity = activityViewController.view.reactive.makeBindingTarget { (view: NSView, input: (Bool, AnimationSettings)) in
            let (show, animationSettings) = input
            animationSettings.animate(in: self.view, changes: { view.isHidden = !show })
        }

        showActivity <~ SignalProducer.combineLatest(activityViewController.wantsDisplay.producer.skipRepeats(),
                                                     animationSettings.producer.skipNil())

        lifetime.observeEnded {
            _ = showActivity
        }
    }
}
