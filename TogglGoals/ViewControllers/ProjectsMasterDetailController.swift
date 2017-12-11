//
//  ProjectsMasterDetailController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

class ProjectsMasterDetailController: NSSplitViewController {

    // MARK: - Exposed targets

    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }
    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    internal var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }
    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }


    // MARK: - Backing properties

    private let _now = MutableProperty<Date?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)


    // MARK: - Projects, goals and reports providing

    internal func setActions(fetchProjectIDs: FetchProjectIDsByGoalsAction,
                             readProject: ReadProjectAction,
                             readGoal: ReadGoalAction,
                             writeGoal: WriteGoalAction,
                             deleteGoal: DeleteGoalAction,
                             readReport: ReadReportAction) {
        areChildrenControllersAvailable.firstTrue.startWithValues { [unowned self] _ in
            self.projectsListViewController
                .setActions(fetchProjectIDs: fetchProjectIDs,
                            readProject: readProject,
                            readGoal: readGoal,
                            readReport: readReport)
            self.selectionDetailViewController
                .setActions(readGoal: readGoal,
                            writeGoal: writeGoal,
                            deleteGoal: deleteGoal,
                            readReport: readReport)
        }
    }


    // MARK: - Contained view controllers

    /// Represents the two split items this controller contains
    private enum SplitItemIndex: Int {
        case projectsList = 0
        case selectionDetail
    }

    private var projectsListViewController: ProjectsListViewController {
        return splitViewItem(.projectsList).viewController as! ProjectsListViewController
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

        projectsListViewController.connectInputs(runningEntry: _runningEntry.producer,
                                                 now: _now.producer.skipNil())

        let detailController = selectionDetailViewController

        detailController.now <~ _now.producer.skipNil()
        detailController.calendar <~ _calendar.producer.skipNil()
        detailController.periodPreference <~ _periodPreference.producer.skipNil()
        detailController.runningEntry <~ _runningEntry

        detailController.project <~ projectsListViewController.selectedProject

        areChildrenControllersAvailable.value = true
    }
}
