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

class ProjectsListActivitySplitViewController: NSSplitViewController {

    internal func connectInputs(projectIDsByGoals: ProjectIDsByGoalsProducer,
                                runningEntry: SignalProducer<RunningEntry?, NoError>,
                                currentDate: SignalProducer<Date, NoError>,
                                modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>) {
        enforceOnce(for: "ProjectsListActivitySplitViewController.connectInputs()") {
            self.isProjectsListViewControllerAvailable.firstTrue.startWithValues { [unowned self] in
                self.projectsListViewController.connectInputs(projectIDsByGoals: projectIDsByGoals,
                                                              runningEntry: runningEntry,
                                                              currentDate: currentDate)
            }

            self.isActivityViewControllerAvailable.firstTrue.startWithValues { [unowned self] in
                self.activityViewController.connectInterface(modelRetrievalStatus: modelRetrievalStatus)
            }
        }
    }

    internal func setActions(readProject: @escaping (ProjectID) -> SignalProducer<Project?, NoError>,
                             readGoal: @escaping (ProjectID) -> SignalProducer<Goal?, NoError>,
                             readReport: @escaping (ProjectID) -> SignalProducer<TwoPartTimeReport?, NoError>) {
        enforceOnce(for: "ProjectsListActivitySplitViewController.setActions()") {
            self.isProjectsListViewControllerAvailable.firstTrue.startWithValues { [unowned self] in
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

    private let isProjectsListViewControllerAvailable = MutableProperty(false)
    private let isActivityViewControllerAvailable = MutableProperty(false)

    // MARK: -

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        for item in splitViewItems {
            let controller = item.viewController
            if let projects = controller as? ProjectsListViewController {
                projectsListViewController = projects
                isProjectsListViewControllerAvailable.value = true
            } else if let activity = controller as? ActivityViewController {
                activityViewController = activity
                isActivityViewControllerAvailable.value = true
            }
        }

        _selectedProjectID <~ projectsListViewController.selectedProjectID

        let expandActivity: BindingTarget<Void> = splitViewItem(for: activityViewController)!.reactive.makeBindingTarget { (splitItem, Void) in
            if splitItem.isCollapsed {
                splitItem.animator().isCollapsed = false
            }
        }
        let collapseActivity: BindingTarget<Void> = splitViewItem(for: activityViewController)!.reactive.makeBindingTarget { (splitItem, Void) in
            if !splitItem.isCollapsed {
                splitItem.animator().isCollapsed = true
            }
        }

        expandActivity <~ activityViewController.wantsDisplay.producer.filter { $0 }.map { _ in () }
        //collapseActivity <~ activityViewController.wantsDisplay.producer.filter { !$0 }.map { _ in () }

        lifetime.observeEnded {
            _ = expandActivity
            _ = collapseActivity
        }
    }
}
