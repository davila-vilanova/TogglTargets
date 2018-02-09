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

    // MARK: - Inputs and Actions

    internal func connectInputs(projectID: SignalProducer<ProjectID?, NoError>,
                                currentDate: SignalProducer<Date, NoError>,
                                calendar: SignalProducer<Calendar, NoError>,
                                periodPreference: SignalProducer<PeriodPreference, NoError>,
                                runningEntry: SignalProducer<RunningEntry?, NoError>) {

        enforceOnce(for: "SelectionDetailViewController.connectInputs()") {
            self.selectedProjectID <~ projectID

            self.areChildrenControllersAvailable.firstTrue.startWithValues {
                self.projectDetailsViewController.connectInputs(project: self.selectedProject.skipNil(),
                                                                currentDate: currentDate,
                                                                calendar: calendar,
                                                                periodPreference: periodPreference,
                                                                runningEntry: runningEntry)
            }
        }
    }

    internal func setActions(readProject: @escaping (ProjectID) -> SignalProducer<Project?, NoError>,
                             readGoal: @escaping (ProjectID) -> SignalProducer<Goal?, NoError>,
                             writeGoal: WriteGoalAction,
                             deleteGoal: DeleteGoalAction,
                             readReport: @escaping (ProjectID) -> SignalProducer<TwoPartTimeReport?, NoError>) {
        enforceOnce(for: "SelectionDetailViewController.setActions()") {
            self.readProject.value = readProject

            self.areChildrenControllersAvailable.firstTrue.startWithValues {
                [unowned self] in
                self.projectDetailsViewController
                    .setActions(readGoal: readGoal,
                                writeGoal: writeGoal,
                                deleteGoal: deleteGoal,
                                readReport: readReport)
            }
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

    private let areChildrenControllersAvailable = MutableProperty(false)

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [ProjectDetailsVCContainment, EmtpySelectionVCContainment])
        setupContainedViewControllerVisibility()
        areChildrenControllersAvailable.value = true
    }
}
