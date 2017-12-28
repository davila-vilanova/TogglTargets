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

    internal func connectInputs(runningEntry: SignalProducer<RunningEntry?, NoError>,
                                currentDate: SignalProducer<Date, NoError>,
                                runningActivities: SignalProducer<Set<RetrievalActivity>, NoError>) {
        isProjectsListViewControllerAvailable.firstTrue.startWithValues { [unowned self] in
            self.projectsListViewController.connectInputs(runningEntry: runningEntry, currentDate: currentDate)
        }

        isActivityViewControllerAvailable.firstTrue.startWithValues { [unowned self] in
            self.activityViewController.connectInputs(activities: runningActivities)
        }
    }

    internal func setActions(fetchProjectIDs: FetchProjectIDsByGoalsAction,
                             readProject: ReadProjectAction,
                             readGoal: ReadGoalAction,
                             readReport: ReadReportAction) {
        isProjectsListViewControllerAvailable.firstTrue.startWithValues { [unowned self] in
            self.projectsListViewController.setActions(fetchProjectIDs: fetchProjectIDs,
                                                       readProject: readProject,
                                                       readGoal: readGoal,
                                                       readReport: readReport)
        }
    }

    internal lazy var selectedProject = Property(_selectedProject)
    private let _selectedProject = MutableProperty<Project?>(nil)

    // MARK: - Contained view controllers

    /// Represents the two split items this controller contains
    private enum SplitItemIndex: Int {
        case projectsList = 0
        case activity
    }

    // MARK: -

    private var projectsListViewController: ProjectsListViewController {
        let vc = splitViewItem(.projectsList).viewController as! ProjectsListViewController
        isProjectsListViewControllerAvailable.value = true
        return vc
    }

    private var activityViewController: ActivityViewController {
        let vc = splitViewItem(.activity).viewController as! ActivityViewController
        isActivityViewControllerAvailable.value = true
        return vc
    }

    private func splitViewItem(_ index: SplitItemIndex) -> NSSplitViewItem {
        return splitViewItems[index.rawValue]
    }

    private let isProjectsListViewControllerAvailable = MutableProperty(false)
    private let isActivityViewControllerAvailable = MutableProperty(false)

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        _selectedProject <~ projectsListViewController.selectedProject
        _ = activityViewController // make it explicitly available
    }
    
}
