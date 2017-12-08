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

    // TODO: make binding target
    internal func setProjectIDsByGoals(_ producer: SignalProducer<ProjectIDsByGoals.Update, NoError>) {
        doAfterViewIsLoaded { [unowned self] in
            self.projectsListViewController.projectIDsByGoals <~ producer
        }
    }
    
    internal var readProjectAction: Action<ProjectID, Property<Project?>, NoError>! {
        didSet {
            doAfterViewIsLoaded { [unowned self] in
                self.projectsListViewController.readProjectAction = self.readProjectAction
            }
        }
    }

    internal func setGoalActions(read readAction: ReadGoalAction,
                                 write writeAction: WriteGoalAction,
                                 delete deleteAction: DeleteGoalAction) {
        // Propagate value to contained controllers once they are available
        doAfterViewIsLoaded { [unowned self] in
            self.projectsListViewController.readGoalAction = readAction
            self.selectionDetailViewController.setGoalActions(read: readAction, write: writeAction, delete: deleteAction)
        }
    }

    internal var readReportAction: Action<ProjectID, Property<TwoPartTimeReport?>, NoError>! {
        didSet {
            doAfterViewIsLoaded { [unowned self] in
                self.projectsListViewController.readReportAction = self.readReportAction
                self.selectionDetailViewController.readReportAction = self.readReportAction
            }
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


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        let listController = projectsListViewController, detailController = selectionDetailViewController
        listController.runningEntry <~ _runningEntry
        listController.now <~ _now.producer.skipNil()

        detailController.now <~ _now.producer.skipNil()
        detailController.calendar <~ _calendar.producer.skipNil()
        detailController.periodPreference <~ _periodPreference.producer.skipNil()
        detailController.runningEntry <~ _runningEntry

        detailController.project <~ listController.selectedProject
    }
}
