//
//  ProjectDetailsViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import PureLayout

fileprivate let GoalVCContainment = "GoalVCContainment"
fileprivate let GoalReportVCContainment = "GoalReportVCContainment"
fileprivate let NoGoalVCContainment = "NoGoalVCContainment"

class ProjectDetailsViewController: NSViewController, ViewControllerContaining, ModelCoordinatorContaining, GoalViewControllerDelegate, NoGoalViewControllerDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var goalView: NSView!
    @IBOutlet weak var goalReportView: NSView!

    
    // MARK: - Contained view controllers
    
    var goalViewController: GoalViewController! {
        didSet {
            goalViewController.calendar = calendar
            goalViewController.strategyComputer = strategyComputer
            goalViewController.delegate = self
            displayController(goalViewController, in: goalView)
        }
    }
    
    var goalReportViewController: GoalReportViewController! {
        didSet {
            goalReportViewController.calendar = calendar
            goalReportViewController.strategyComputer = strategyComputer
            goalReportViewController.now = now
            goalReportViewController.runningEntryProperty = modelCoordinator!.runningEntry
        }
    }
    var noGoalViewController: NoGoalViewController! {
        didSet {
            noGoalViewController.delegate = self
        }
    }

    
    // MARK: - Represented data
    
    var representedProject: Project? {
        didSet {
            displayProjectAndBindGoalAndReport()
        }
    }
    
    private var observedGoalProperty: ObservedProperty<TimeGoal?>?

    
    //  MARK: - Infrastructure
    
    var modelCoordinator: ModelCoordinator?
    var now = Date()
    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }()

    let strategyComputer = StrategyComputer(calendar: Calendar(identifier: .iso8601))
    
    
    //  MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        for identifier in [GoalVCContainment, GoalReportVCContainment, NoGoalVCContainment] {
            performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: identifier), sender: self)
        }
        
        displayProjectAndBindGoalAndReport()
    }
    
    private func displayProjectAndBindGoalAndReport() {
        guard isViewLoaded == true,
            let project = self.representedProject,
            let mc = modelCoordinator else {
            return;
        }

        if let name = project.name {
            projectName.stringValue = name
        } else {
            projectName.stringValue = "(no name)"
        }

        let goalProperty = mc.goalProperty(for: project.id)
        observeGoalProperty(goalProperty).reportImmediately()
        goalViewController.goalProperty = goalProperty
        
        let reportProperty = mc.reportProperty(for: project.id)
        
        goalReportViewController.setGoalProperty(goalProperty, reportProperty: reportProperty)
    }
    
    @discardableResult
    private func observeGoalProperty(_ goalProperty: Property<TimeGoal?>) -> ObservedProperty<TimeGoal?> {
        func goalDidChange(_ observedGoal: ObservedProperty<TimeGoal?>?) {
            let goalExists = (observedGoal?.original?.value != nil)
            let controller = goalExists ? goalReportViewController : noGoalViewController
            displayController(controller, in: goalReportView)
        }
        
        func goalWasInvalidated() {
            goalDidChange(nil)
        }
        
        observedGoalProperty?.unobserve()
        let observed = ObservedProperty<TimeGoal?>(original: goalProperty, valueObserver: goalDidChange, invalidationObserver: goalWasInvalidated)
        observedGoalProperty = observed
        return observed
    }
    
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
    
    func onCreateGoalAction() {
        guard observedGoalProperty?.original?.value == nil,
            let modelCoordinator = self.modelCoordinator,
            let projectId = representedProject?.id else {
                return
        }
        let goal = TimeGoal(forProjectId: projectId, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend)
        modelCoordinator.setNewGoal(goal)
    }
    
    func onDeleteGoalAction() {
        guard let goal = observedGoalProperty?.original?.value,
            let modelCoordinator = self.modelCoordinator else {
                return
        }
        modelCoordinator.deleteGoal(goal)
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
