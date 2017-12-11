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

    // MARK: - Exposed targets

    internal var project: BindingTarget<Project?> { return _project.bindingTarget }

    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }
    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    internal var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }
    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }


    // MARK: - Backing properties

    private let _project = MutableProperty<Project?>(nil)

    private let _now = MutableProperty<Date?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)


    // MARK: - Actions

    internal func setActions(readGoal: ReadGoalAction,
                             writeGoal: WriteGoalAction,
                             deleteGoal: DeleteGoalAction,
                             readReport: ReadReportAction) {
        areChildrenControllersAvailable.firstTrue.startWithValues {
            [unowned self] in
            self.projectDetailsViewController
                .setActions(readGoal: readGoal,
                            writeGoal: writeGoal,
                            deleteGoal: deleteGoal,
                            readReport: readReport)
        }
    }


    // MARK: - Local use of project

    private func setupContainedViewControllerVisibility() {
        _project.producer.map { $0 != nil }.observe(on: UIScheduler())
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

    var projectDetailsViewController: ProjectDetailsViewController! {
        didSet {
            if let controller = projectDetailsViewController {
                controller.project <~ _project.producer.skipNil()
                controller.now <~ _now.producer.skipNil()
                controller.calendar <~ _calendar.producer.skipNil()
                controller.periodPreference <~ _periodPreference.producer.skipNil()
                controller.runningEntry <~ _runningEntry
            }
        }
    }

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
