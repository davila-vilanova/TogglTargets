//
//  ProjectDetailsViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import PureLayout
import ReactiveSwift
import ReactiveCocoa
import Result

fileprivate let GoalVCContainment = "GoalVCContainment"
fileprivate let GoalReportVCContainment = "GoalReportVCContainment"
fileprivate let NoGoalVCContainment = "NoGoalVCContainment"

class ProjectDetailsViewController: NSViewController, ViewControllerContaining {

    // MARK: - Outlets
    
    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var goalView: NSView!
    @IBOutlet weak var goalReportView: NSView!

    
    // MARK: - Contained view controllers

    var goalViewController: GoalViewController!

    var goalReportViewController: GoalReportViewController!

    var noGoalViewController: NoGoalViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller {
        case _ where (controller as? GoalViewController) != nil:
            goalViewController = controller as! GoalViewController
        case _ where (controller as? GoalReportViewController) != nil:
            goalReportViewController = controller as! GoalReportViewController
        case _ where (controller as? NoGoalViewController) != nil:
            noGoalViewController = controller as! NoGoalViewController
        default: break
        }
    }

    private func setupConnectionsToContainedViewControllers() {
        goalViewController.goal <~ goal
        goalViewController.userUpdates.observe(goalUserUpdatesPipe.input)

        goalReportViewController.goal <~ goal
        goalReportViewController.report <~ report
        goalReportViewController.calendar <~ calendar
        goalReportViewController.now <~ now
        goalReportViewController.runningEntry <~ runningEntry

        noGoalViewController.projectId <~ _project.map { $0?.id }
        noGoalViewController.goalCreated.map { Optional($0) }.observe(goalUserUpdatesPipe.input)
    }

    private func setupContainedViewControllerVisibility() {
        displayController(goalViewController, in: goalView) // Displays always

        goal.producer.filter { $0 == nil }.observe(on: UIScheduler()).startWithValues { [weak self] _ in
            guard let vc = self else { return }
            displayController(vc.noGoalViewController, in: vc.goalReportView)
        }

        goal.producer.filter { $0 != nil }.observe(on: UIScheduler()).startWithValues { [weak self] _ in
            guard let vc = self else { return }
            displayController(vc.goalReportViewController, in: vc.goalReportView)
        }
    }

    // MARK: - Data flow from parent view controller

    var project: BindingTarget<Project?> { return _project.bindingTarget }


    // MARK: - Data flow to contained view controllers

    private let goal = MutableProperty<TimeGoal?>(nil)
    private let report = MutableProperty<TwoPartTimeReport?>(nil)
    private let _project = MutableProperty<Project?>(nil)
    private let calendar = MutableProperty<Calendar?>(nil)
    private let now = MutableProperty<Date?>(nil)
    private let runningEntry = MutableProperty<RunningEntry?>(nil)


    // MARK: - Data flow from contained view controllers

    private let goalUserUpdatesPipe = Signal<TimeGoal?, NoError>.pipe()

    
    // MARK: - ModelCoordinator

    var modelCoordinator: ModelCoordinator? {
        didSet {
            setupDataFlowWithModelCoordinator()
        }
    }

    private var exclusiveBindingDisposables = DisposableBag()
    private func setupDataFlowWithModelCoordinator() {
        guard let modelCoordinator = modelCoordinator else {
            return
        }
        calendar <~ modelCoordinator.calendar
        now <~ modelCoordinator.now
        runningEntry <~ modelCoordinator.runningEntry

        _project.producer.skipNil().startWithValues { [weak self] projectValue in
            guard let s = self else {
                return
            }
            let goalForThisProject = modelCoordinator.goalProperty(for: projectValue.id)
            let reportForThisProject = modelCoordinator.reportProperty(for: projectValue.id)

            s.exclusiveBindingDisposables.disposeAll()

            // Bindings from MC
            s.exclusiveBindingDisposables.put(s.goal <~ goalForThisProject)
            s.exclusiveBindingDisposables.put(s.report <~ reportForThisProject)

            // Bindings to MC
            s.exclusiveBindingDisposables.put(goalForThisProject.bindingTarget <~ s.goalUserUpdatesPipe.output)
        }
    }


    //  MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [GoalVCContainment, GoalReportVCContainment, NoGoalVCContainment])
        setupLocalProjectDisplay()
        setupConnectionsToContainedViewControllers()
        setupContainedViewControllerVisibility()
    }

    private func setupLocalProjectDisplay() {
        _project.producer.observe(on: UIScheduler()).startWithValues { [weak self] projectOrNil in
            self?.projectName.stringValue = projectOrNil?.name ?? (projectOrNil != nil ? "(unnamed project)" : "(no project selected)")
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
