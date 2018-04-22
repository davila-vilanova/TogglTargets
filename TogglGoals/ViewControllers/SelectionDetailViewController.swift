//
//  SelectionDetailViewController.swift
//  TogglGoals
//
//  Created by David Davila on 03.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

fileprivate let ProjectDetailsVCContainment = "ProjectDetailsVCContainment"
fileprivate let EmtpySelectionVCContainment = "EmtpySelectionVCContainment"

class SelectionDetailViewController: NSViewController, ViewControllerContaining {

    // MARK: - Interface

    internal typealias Interface =
        (projectId: SignalProducer<ProjectID?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        calendar: SignalProducer<Calendar, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        readProject: ReadProject,
        readGoal: ReadGoal,
        writeGoal: BindingTarget<Goal>,
        deleteGoal: BindingTarget<ProjectID>,
        readReport: ReadReport)

    private let _interface = MutableProperty<Interface?>(nil)
    internal var interface: BindingTarget<Interface?> { return _interface.bindingTarget }

    private func connectInterface() {
        selectedProjectID <~ _interface.latestOutput { $0.projectId }
        readProject <~ _interface.producer.skipNil().map { $0.readProject }

        projectDetailsViewController.interface <~
            SignalProducer.combineLatest(SignalProducer(value: selectedProject.skipNil()),
                                         _interface.producer.skipNil())
                .map {
                    selectedProjectProducer, ownInterface in
                    (selectedProjectProducer,
                     ownInterface.currentDate,
                     ownInterface.calendar,
                     ownInterface.periodPreference,
                     ownInterface.runningEntry,
                     ownInterface.readGoal,
                     ownInterface.writeGoal,
                     ownInterface.deleteGoal,
                     ownInterface.readReport)
        }
    }


    // MARK: - Local use of project

    private let readProject = MutableProperty<((ProjectID) -> SignalProducer<Project?, NoError>)?>(nil)
    private let selectedProjectID = MutableProperty<ProjectID?>(nil)
    private lazy var selectedProject: SignalProducer<Project?, NoError> = selectedProjectID.producer
        .throttle(while: readProject.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readProject.producer.skipNil())
        .map { projectID, readProject -> SignalProducer<Project?, NoError> in
            if let projectID = projectID {
                return readProject(projectID)
            } else {
                return SignalProducer(value: nil)
            }
        }
        .flatten(.latest)


    private func setupContainedViewControllerVisibility() {
        selectedProject.producer.map { $0 != nil }.observe(on: UIScheduler())
            .startWithValues { [projectDetailsViewController, emptySelectionViewController, view] projectAvailable in
                guard let projectDetailsViewController = projectDetailsViewController,
                    let emptySelectionViewController = emptySelectionViewController else {
                        return
                }
                let containedVC = projectAvailable ? projectDetailsViewController : emptySelectionViewController
                displayController(containedVC, in: view)
        }
    }


    // MARK: - Contained view controllers

    var projectDetailsViewController: ProjectDetailsViewController!

    var emptySelectionViewController: EmptySelectionViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller {
        case _ where (controller as? ProjectDetailsViewController) != nil:
            projectDetailsViewController = controller as! ProjectDetailsViewController
        case _ where (controller as? EmptySelectionViewController) != nil:
            emptySelectionViewController = controller as! EmptySelectionViewController
        default: break
        }
    }


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [ProjectDetailsVCContainment, EmtpySelectionVCContainment])

        connectInterface()

        setupContainedViewControllerVisibility()
    }
}
