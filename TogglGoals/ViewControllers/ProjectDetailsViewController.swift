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

    // MARK: - Inputs

    internal func connectInputs(project: SignalProducer<Project, NoError>,
                                currentDate: SignalProducer<Date, NoError>,
                                calendar: SignalProducer<Calendar, NoError>,
                                periodPreference: SignalProducer<PeriodPreference, NoError>,
                                runningEntry: SignalProducer<RunningEntry?, NoError>) {
        enforceOnce(for: "ProjectDetailsViewController.connectInputs()") {
            self.project <~ project

            self.areChildrenControllersAvailable.firstTrue.startWithValues {
                self.goalReportViewController.connectInputs(projectId: self.projectId,
                                                            goal: self.goalForCurrentProject.skipNil(),
                                                            report: self.report.producer,
                                                            runningEntry: runningEntry,
                                                            calendar: calendar,
                                                            currentDate: currentDate,
                                                            periodPreference: periodPreference)

                self.goalViewController.connectInputs(goal: self.goalForCurrentProject,
                                                      calendar: calendar)

                self.noGoalViewController.connectInputs(projectId: self.projectId)
            }
        }
    }


    // MARK: - Private properties

    /// Selected project.
    private let project = MutableProperty<Project?>(nil)

    /// Report corresponding to the selected project.
    private let report = MutableProperty<TwoPartTimeReport?>(nil)


    // MARK: - Derived input

    private lazy var projectId: SignalProducer<Int64, NoError> = project.producer.skipNil().map { $0.id }


    // MARK: - Goal and report retrieving actions

    internal func setActions(readGoal: @escaping (ProjectID) -> SignalProducer<Goal?, NoError>,
                             writeGoal: WriteGoalAction,
                             deleteGoal: DeleteGoalAction,
                             readReport: ReadReportAction) {

        enforceOnce(for: "ProjectDetailsViewController.setActions()") {
            self.readGoal.value = readGoal
            self.writeGoalAction = writeGoal
            self.deleteGoalAction = deleteGoal
            self.readReportAction = readReport

            self.areChildrenControllersAvailable.firstTrue.startWithValues {
                self.setupConnectionsWithActions()
            }
        }
    }

    private let readGoal = MutableProperty<((ProjectID) -> SignalProducer<Goal?, NoError>)?>(nil)

    /// Goal corresponding to the selected project.
    private lazy var goalForCurrentProject: SignalProducer<Goal?, NoError> = projectId
        .throttle(while: readGoal.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readGoal.producer.skipNil())
        .map { projectId, readGoal in readGoal(projectId) }
        .flatten(.latest)


    private var writeGoalAction: WriteGoalAction!
    private var deleteGoalAction: DeleteGoalAction!
    internal var readReportAction: ReadReportAction!

    private func setupConnectionsWithActions() {
        // `goal` and `report` will only track values associated with the current project
        report <~ readReportAction.values.flatten(.latest)

        // Retrieve corresponding goal and report when project ID changes
        readReportAction.serialInput <~ projectId

        // Trigger `writeGoalAction` when current goal changes or a goal is created
        writeGoalAction!.serialInput <~ Signal.merge(goalViewController.userUpdates.skipNil(),
                                                     noGoalViewController.goalCreated)

        // Trigger `deleteGoalAction` when a goal is deleted
        let deleteSignal = goalViewController.userUpdates.filter { $0 == nil}.map { _ in () }
        deleteGoalAction!.serialInput <~ projectId.sample(on: deleteSignal)
    }


    // MARK: - Contained view controllers

    var goalViewController: GoalViewController!

    var goalReportViewController: GoalReportViewController!

    var noGoalViewController: NoGoalViewController!

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

        goalForCurrentProject.filter { $0 == nil }.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            displayController(self.noGoalViewController, in: self.goalReportView)
        }

        goalForCurrentProject.filter { $0 != nil }.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            displayController(self.goalReportViewController, in: self.goalReportView)
        }
    }

    private let areChildrenControllersAvailable = MutableProperty(false)

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

        areChildrenControllersAvailable.value = true
    }

    private func setupLocalProjectDisplay() {
        project.producer.observe(on: UIScheduler()).startWithValues { [unowned self] projectOrNil in
            self.projectName.stringValue = projectOrNil?.name ?? (projectOrNil != nil ? "(unnamed project)" : "(no project selected)")
        }
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
