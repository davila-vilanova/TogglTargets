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

    internal var projects: BindingTarget<[Int64 : Project]> { return _projects.deoptionalizedBindingTarget }
    internal var goals: BindingTarget<[Int64 : Goal]> { return _goals.deoptionalizedBindingTarget }

    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }
    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    internal var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }
    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }


    // MARK: - Backing properties

    private let _projects = MutableProperty<[Int64 : Project]?>(nil)
    private let _goals = MutableProperty<[Int64 : Goal]?>(nil)

    private let _now = MutableProperty<Date?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)


    // MARK: - Goal and report providing

    internal func setGoalActions(read readAction: Action<ProjectID, Property<Goal?>, NoError>,
                                 write writeAction: Action<Goal, Void, NoError>,
                                 delete deleteAction: Action<ProjectID, Void, NoError>) {
        // Propagate value to contained controllers once they are available
        doAfterViewIsLoaded { [unowned self] in
            self.projectsListViewController.readGoalAction = readAction
            self.selectionDetailViewController.setGoalActions(read: readAction, write: writeAction, delete: deleteAction)
        }
    }

    internal var reportReadProviderProducer: SignalProducer<Action<Int64, Property<TwoPartTimeReport?>, NoError>, NoError>! {
        didSet {
            assert(reportReadProviderProducer != nil)
            assert(oldValue == nil)
            doAfterViewIsLoaded { [unowned self, producer = reportReadProviderProducer] in
                self.projectsListViewController.reportReadProviderProducer = producer
                self.selectionDetailViewController.reportReadProviderProducer = producer
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
        listController.projects <~ _projects.producer.skipNil()
        listController.goals <~ _goals.producer.skipNil()
        listController.runningEntry <~ _runningEntry
        listController.now <~ _now.producer.skipNil()

        detailController.now <~ _now.producer.skipNil()
        detailController.calendar <~ _calendar.producer.skipNil()
        detailController.periodPreference <~ _periodPreference.producer.skipNil()
        detailController.runningEntry <~ _runningEntry

        detailController.project <~ listController.selectedProject
    }
}
