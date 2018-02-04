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
                self.activityViewController.connectInputs(modelRetrievalStatus: modelRetrievalStatus)
            }
        }
    }

    internal func setActions(readProject: ReadProjectAction,
                             readGoal: ReadGoalAction,
                             readReport: ReadReportAction) {
        enforceOnce(for: "ProjectsListActivitySplitViewController.setActions()") {
            self.isProjectsListViewControllerAvailable.firstTrue.startWithValues { [unowned self] in
                self.projectsListViewController.setActions(readProject: readProject,
                                                           readGoal: readGoal,
                                                           readReport: readReport)
            }
        }
    }

    internal lazy var selectedProject = Property(_selectedProject)
    private let _selectedProject = MutableProperty<Project?>(nil)

    // MARK: - Contained view controllers

    private var projectsListViewController: ProjectsListViewController!
    private var activityViewController: ActivityViewController!

    private let isProjectsListViewControllerAvailable = MutableProperty(false)
    private let isActivityViewControllerAvailable = MutableProperty(false)

    // MARK: -

    var keepAround = [BindingTarget<Void>]()

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

        _selectedProject <~ projectsListViewController.selectedProject

        let expandActivity: BindingTarget<Void> = splitViewItem(for: activityViewController)!.reactive.makeBindingTarget { (splitItem, Void) in
            splitItem.animator().isCollapsed = false
        }
        let collapseActivity: BindingTarget<Void> = splitViewItem(for: activityViewController)!.reactive.makeBindingTarget { (splitItem, Void) in
            splitItem.animator().isCollapsed = true
        }

        expandActivity <~ activityViewController.wantsDisplay.producer.filter { $0 }.map { _ in () }
        collapseActivity <~ activityViewController.wantsDisplay.producer.filter { !$0 }.map { _ in () }

        keepAround.append(expandActivity)
        keepAround.append(collapseActivity)
    }

    func expandActivity() {
        splitViewItem(for: activityViewController)!.animator().isCollapsed = false
    }

}
