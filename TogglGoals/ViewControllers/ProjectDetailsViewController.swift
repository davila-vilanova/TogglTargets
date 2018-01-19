//
//  ProjectDetailsViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

fileprivate let GoalVCContainment = "GoalVCContainment"
fileprivate let GoalReportVCContainment = "GoalReportVCContainment"
fileprivate let NoGoalVCContainment = "NoGoalVCContainment"

class ProjectDetailsViewController: NSViewController, ViewControllerContaining {

    // MARK: - Exposed targets

    internal var project: BindingTarget<Project> { return _project.deoptionalizedBindingTarget }
    internal var currentDate: BindingTarget<Date> { return _currentDate.deoptionalizedBindingTarget }
    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    internal var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }
    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }


    // MARK: - Private properties

    private let _project = MutableProperty<Project?>(nil)
    private let _currentDate = MutableProperty<Date?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)


    /// goalDownstream holds and propagates the values read by this controller and subcontrollers
    /// of the currently selected goal, if any.
    private let goalDownstream = MutableProperty<Goal?>(nil)


    // MARK: - Derived input

    private lazy var projectId: SignalProducer<Int64, NoError> = _project.producer.skipNil().map { $0.id }



    // MARK: - Goal and report providing

    internal func setActions(readGoal: ReadGoalAction,
                             writeGoal: WriteGoalAction,
                             deleteGoal: DeleteGoalAction,
                             readReport: ReadReportAction) {
        assert(readGoalAction == nil,
               "ProjectDetailsViewController's actions must be set exactly once.")

        readGoalAction = readGoal
        writeGoalAction = writeGoal
        deleteGoalAction = deleteGoal
        readReportAction = readReport
    }

    private var readGoalAction: ReadGoalAction?
    private var writeGoalAction: WriteGoalAction?
    private var deleteGoalAction: DeleteGoalAction?

    internal var readReportAction: ReadReportAction?

    private func setupConnectionsWithActions() {
        // This ensures that goalDownstream will only listen to values associated with the current project
        goalDownstream <~ readGoalAction!.values.flatten(.latest)
        goalReportViewController.report <~ readReportAction!.values.flatten(.latest)

        // Retrieve corresponding goal and report when project ID changes
        readGoalAction!.serialInput <~ projectId
        readReportAction!.serialInput <~ projectId

        writeGoalAction!.serialInput <~ Signal.merge(goalViewController.userUpdates.skipNil(),
                                                     noGoalViewController.goalCreated)

        let deleteSignal = goalViewController.userUpdates.filter { $0 == nil}.map { _ in () }
        deleteGoalAction!.serialInput <~ projectId.sample(on: deleteSignal)
    }


    // MARK: - Local use of project

    private func setupLocalProjectDisplay() {
        _project.producer.observe(on: UIScheduler()).startWithValues { [unowned self] projectOrNil in
            self.projectName.stringValue = projectOrNil?.name ?? (projectOrNil != nil ? "(unnamed project)" : "(no project selected)")
        }
    }


    // MARK: - Contained view controllers

    var goalViewController: GoalViewController! {
        didSet {
            if let controller = goalViewController {
                controller.goal <~ goalDownstream
                controller.calendar <~ _calendar.producer.skipNil()
            }
        }
    }

    var goalReportViewController: GoalReportViewController! {
        didSet {
            if let controller = goalReportViewController {
                controller.projectId <~ projectId
                controller.currentDate <~ _currentDate.producer.skipNil()
                controller.goal <~ goalDownstream.producer.skipNil()
                controller.calendar <~ _calendar.producer.skipNil()
                controller.periodPreference <~ _periodPreference.producer.skipNil()
                controller.runningEntry <~ _runningEntry.producer
            }
        }
    }

    var noGoalViewController: NoGoalViewController! {
        didSet {
            if let controller = noGoalViewController {
                controller.projectId <~ projectId
            }
        }
    }

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller { // TODO: rework cases
        case _ where (controller as? GoalViewController) != nil:
            goalViewController = controller as! GoalViewController
        case _ where (controller as? GoalReportViewController) != nil:
            goalReportViewController = controller as! GoalReportViewController
        case _ where (controller as? NoGoalViewController) != nil:
            noGoalViewController = controller as! NoGoalViewController
        default: break
        }
    }

    private func setupContainedViewControllerVisibility() {
        displayController(goalViewController, in: goalView) // Display always

        goalDownstream.producer.filter { $0 == nil }.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            displayController(self.noGoalViewController, in: self.goalReportView)
        }

        goalDownstream.producer.filter { $0 != nil }.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            displayController(self.goalReportViewController, in: self.goalReportView)
        }
    }


    // MARK: - Outlets

    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var goalView: NSView!
    @IBOutlet weak var goalReportView: NSView!


    //  MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [GoalVCContainment, GoalReportVCContainment, NoGoalVCContainment])
        setupLocalProjectDisplay()
        setupContainedViewControllerVisibility()
        setupConnectionsWithActions()
    }
}

class ColoredView: NSView {
    var backgroundColor: NSColor? {
        didSet {
            let cgColor: CGColor?
            if let color = backgroundColor {
                cgColor = color.cgColor
            } else {
                cgColor = nil
            }

            // TODO: learn about the right timing to apply the color without this megahack
            let delay = DispatchTime.now() + .seconds(1)
            DispatchQueue.main.asyncAfter(deadline: delay) {
                self.layer?.backgroundColor = cgColor
            }
        }
    }
}
