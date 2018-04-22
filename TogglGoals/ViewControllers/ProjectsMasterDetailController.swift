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

    // MARK: - Interface

    internal typealias Interface = (
        calendar: SignalProducer<Calendar, NoError>,
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
    private let (lifetime, token) = Lifetime.make()

    private func connectInterface() {
        let selectedProjectId = MutableProperty<ProjectID?>(nil)

        lifetime.observeEnded {
            _ = selectedProjectId
        }

        projectsListActivityViewController.interface <~
            SignalProducer.combineLatest(SignalProducer(value: selectedProjectId.bindingTarget),
                                         _interface.producer.skipNil())
                .map { selectedProjectIdTarget, ownInterface in
                    (ownInterface.projectIDsByGoals,
                     selectedProjectIdTarget,
                     ownInterface.runningEntry,
                     ownInterface.currentDate,
                     ownInterface.modelRetrievalStatus,
                     ownInterface.readProject,
                     ownInterface.readGoal,
                     ownInterface.readReport)
        }

        selectionDetailViewController.interface <~
            SignalProducer.combineLatest(SignalProducer(value: selectedProjectId.producer),
                                         _interface.producer.skipNil())
                .map { selectedProjectIdProducer, ownInterface in
                    (selectedProjectIdProducer,
                     ownInterface.currentDate,
                     ownInterface.calendar,
                     ownInterface.periodPreference,
                     ownInterface.runningEntry,
                     ownInterface.readProject,
                     ownInterface.readGoal,
                     ownInterface.writeGoal,
                     ownInterface.deleteGoal,
                     ownInterface.readReport)
        }
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

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        connectInterface()
    }
}
