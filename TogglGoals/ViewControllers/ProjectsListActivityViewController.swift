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

    // Interface

    internal typealias Interface =
        (projectIDsByGoals: ProjectIDsByGoalsProducer,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>,
        readProject: ReadProject,
        readGoal: ReadGoal,
        readReport: ReadReport)

    private let _interface = MutableProperty<Interface?>(nil)
    internal var interface: BindingTarget<Interface?> { return _interface.bindingTarget }

    internal func connectInterface() {
        projectsListViewController.interface <~
            _interface.producer.skipNil().map { ($0.projectIDsByGoals,
                                       $0.runningEntry,
                                       $0.currentDate,
                                       $0.readProject,
                                       $0.readGoal,
                                       $0.readReport) }

        activityViewController.interface <~
            _interface.producer.skipNil().map { [unowned self] in
                ($0.modelRetrievalStatus,
                 self.displayActivity.bindingTarget) }
    }

    private let displayActivity = MutableProperty(false)

    internal lazy var selectedProjectID = _selectedProjectID.producer
    private let _selectedProjectID = MutableProperty<ProjectID?>(nil)

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

        connectInterface()

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
