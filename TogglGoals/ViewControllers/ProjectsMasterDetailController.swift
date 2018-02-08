//
//  ProjectsMasterDetailController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

class ProjectsMasterDetailController: NSSplitViewController {

    // MARK: - Backing properties

    private let _currentDate = MutableProperty<Date?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _modelRetrievalStatus = MutableProperty<ActivityStatus?>(nil)


    // MARK: - Inputs and actions

    internal func connectInputs(calendar: SignalProducer<Calendar, NoError>,
                                periodPreference: SignalProducer<PeriodPreference, NoError>,
                                projectIDsByGoals: ProjectIDsByGoalsProducer,
                                runningEntry: SignalProducer<RunningEntry?, NoError>,
                                currentDate: SignalProducer<Date, NoError>,
                                modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>) {
        enforceOnce(for: "ProjectsMasterDetailController.connectInputs()") {
            self.areChildrenControllersAvailable.firstTrue.startWithValues {
                self.projectsListViewController.connectInputs(projectIDsByGoals: projectIDsByGoals,
                                                              runningEntry: runningEntry,
                                                              currentDate: currentDate,
                                                              modelRetrievalStatus: modelRetrievalStatus)
            }
            self.selectionDetailViewController.connectInputs(project: self.projectsListViewController.selectedProject.producer,
                                                             currentDate: currentDate,
                                                             calendar: calendar,
                                                             periodPreference: periodPreference,
                                                             runningEntry: runningEntry)
        }
    }

    internal func setActions(readProject: ReadProjectAction,
                             readGoal: @escaping (ProjectID) -> SignalProducer<Goal?, NoError>,
                             writeGoal: WriteGoalAction,
                             deleteGoal: DeleteGoalAction,
                             readReport: @escaping (ProjectID) -> SignalProducer<TwoPartTimeReport?, NoError>) {
        enforceOnce(for: "ProjectsMasterDetailController.setActions()") {
            self.areChildrenControllersAvailable.firstTrue.startWithValues { [unowned self] _ in
                self.projectsListViewController
                    .setActions(readProject: readProject,
                                readGoal: readGoal,
                                readReport: readReport)
                self.selectionDetailViewController
                    .setActions(readGoal: readGoal,
                                writeGoal: writeGoal,
                                deleteGoal: deleteGoal,
                                readReport: readReport)
            }
        }
    }


    // MARK: - Contained view controllers

    /// Represents the two split items this controller contains
    private enum SplitItemIndex: Int {
        case projectsList = 0
        case selectionDetail
    }

    private var projectsListViewController: ProjectsListActivitySplitViewController {
        return splitViewItem(.projectsList).viewController as! ProjectsListActivitySplitViewController
    }

    private var selectionDetailViewController: SelectionDetailViewController {
        return splitViewItem(.selectionDetail).viewController as! SelectionDetailViewController
    }

    private func splitViewItem(_ index: SplitItemIndex) -> NSSplitViewItem {
        return splitViewItems[index.rawValue]
    }

    private let areChildrenControllersAvailable = MutableProperty(false)


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        areChildrenControllersAvailable.value = true
    }
}
