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


    // MARK: - Interface

    internal typealias Interface =
        (calendar: SignalProducer<Calendar, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        projectIDsByGoals: ProjectIDsByGoalsProducer,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>,
        readProject: ReadProject,
        readGoal: ReadGoal,
        writeGoal: BindingTarget<Goal>,
        deleteGoal: BindingTarget<ProjectID>,
        readReport: ReadReport)

    private let _interface = MutableProperty<Interface?>(nil)
    internal var interface: BindingTarget<Interface?> { return _interface.bindingTarget }

    private func connectInterface() {
        projectsListActivityViewController.interface <~
            _interface.producer.skipNil().map { ($0.projectIDsByGoals,
                                                 $0.runningEntry,
                                                 $0.currentDate,
                                                 $0.modelRetrievalStatus,
                                                 $0.readProject,
                                                 $0.readGoal,
                                                 $0.readReport) }

        selectionDetailViewController.interface <~
            _interface.producer.skipNil().map {
                [unowned self] in (self.projectsListActivityViewController.selectedProjectID,
                                   $0.currentDate,
                                   $0.calendar,
                                   $0.periodPreference,
                                   $0.runningEntry,
                                   $0.readProject,
                                   $0.readGoal,
                                   $0.writeGoal,
                                   $0.deleteGoal,
                                   $0.readReport) }
    }


    // MARK: - Contained view controllers

    /// Represents the two split items this controller contains
    private enum SplitItemIndex: Int {
        case projectsList = 0
        case selectionDetail
    }

    private var projectsListActivityViewController: ProjectsListActivityViewController {
        return splitViewItem(.projectsList).viewController as! ProjectsListActivityViewController
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

        connectInterface()
    }
}
