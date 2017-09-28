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

    internal var projectsByGoals: BindingTarget<ProjectsByGoals> { return _projectsByGoals.deoptionalizedBindingTarget }
    internal var fullProjectsUpdate: BindingTarget<Bool> { return _fullProjectsUpdate.deoptionalizedBindingTarget }
    internal var cluedProjectsUpdate: BindingTarget<CollectionUpdateClue> { return _cluedProjectsUpdate.deoptionalizedBindingTarget }

    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }
    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }


    // MARK: - Backing properties

    private let _projectsByGoals = MutableProperty<ProjectsByGoals?>(nil)
    private let _fullProjectsUpdate = MutableProperty<Bool?>(nil)
    private let _cluedProjectsUpdate = MutableProperty<CollectionUpdateClue?>(nil)

    private let _now = MutableProperty<Date?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)


    // MARK: - Goal and report providing

    internal var goalReadProviderProducer: SignalProducer<Action<Int64, Property<Goal?>, NoError>, NoError>! {
        didSet {
            // Expect a single, non nil value during the Controller lifecycle
            assert(goalReadProviderProducer != nil)
            assert(oldValue == nil)
            // Propagate value to contained controllers once they are available
            doAfterViewIsLoaded { [unowned self, producer = goalReadProviderProducer] in
                self.projectsListViewController.goalReadProviderProducer = producer
                self.selectionDetailViewController.goalReadProviderProducer = producer
            }
        }
    }
    internal var goalWriteProviderProducer: SignalProducer<Action<Int64, BindingTarget<Goal?>, NoError>, NoError>! {
        didSet {
            assert(goalWriteProviderProducer != nil)
            assert(oldValue == nil)
            doAfterViewIsLoaded { [unowned self, producer = goalWriteProviderProducer] in
                self.selectionDetailViewController.goalWriteProviderProducer = producer
            }
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

    /// Represents the two split items this controller has
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
        listController.projectsByGoals <~ _projectsByGoals.producer.skipNil()
        listController.fullProjectsUpdate <~ _fullProjectsUpdate.producer.skipNil()
        listController.cluedProjectsUpdate <~ _cluedProjectsUpdate.producer.skipNil()

        detailController.now <~ _now.producer.skipNil()
        detailController.calendar <~ _calendar.producer.skipNil()
        detailController.runningEntry <~ _runningEntry

        detailController.project <~ listController.selectedProject
    }
}
