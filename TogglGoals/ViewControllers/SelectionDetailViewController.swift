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

    internal func connectInputs(project: SignalProducer<Project?, NoError>,
                                currentDate: SignalProducer<Date, NoError>,
                                calendar: SignalProducer<Calendar, NoError>,
                                periodPreference: SignalProducer<PeriodPreference, NoError>,
                                runningEntry: SignalProducer<RunningEntry?, NoError>) {

        enforceOnce(for: "SelectionDetailViewController.connectInputs()") {
            self.selectedProject <~ project

            self.areChildrenControllersAvailable.firstTrue.startWithValues {
                self.projectDetailsViewController.project <~ self.selectedProject.producer.skipNil()
                self.projectDetailsViewController.currentDate <~ currentDate
                self.projectDetailsViewController.calendar <~ calendar
                self.projectDetailsViewController.periodPreference <~ periodPreference
                self.projectDetailsViewController.runningEntry <~ runningEntry
            }
        }
    }

    internal func setActions(readGoal: ReadGoalAction,
                             writeGoal: WriteGoalAction,
                             deleteGoal: DeleteGoalAction,
                             readReport: ReadReportAction) {
        enforceOnce(for: "SelectionDetailViewController.setActions()") {
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

    private let selectedProject = MutableProperty<Project?>(nil)

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
