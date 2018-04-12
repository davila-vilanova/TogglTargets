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
                    .connectInterface(modelRetrievalStatus: modelRetrievalStatus,
                                      requestDisplay: self.displayActivity.bindingTarget)
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

    private let displayActivity = MutableProperty(false)

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

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [ProjectsListVCContainment, ActivityVCContainment])

        areViewAndContainedViewControllersAvailable.value = true

        _selectedProjectID <~ projectsListViewController.selectedProjectID

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
