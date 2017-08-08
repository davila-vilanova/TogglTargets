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

    internal func setSelectedProject(_ project: MutableProperty<Project?>) {
        selectedProject <~ project
    }

    private var selectedProject = MutableProperty<Project?>(nil)

    private var observedGoalProperty: ObservedProperty<TimeGoal>?

    
    //  MARK: - Infrastructure
    
    var modelCoordinator: ModelCoordinator? {
        didSet {
            modelCoordinatorP.value = modelCoordinator
        }
    }
    var modelCoordinatorP = MutableProperty<ModelCoordinator?>(nil)

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

        selectedProject.producer.observe(on: UIScheduler()).startWithValues { [weak self] projectOrNil in
            self?.projectName.stringValue = projectOrNil?.name ?? (projectOrNil != nil ? "(unnamed project)" : "(no project selected)")
        }

        let modelCoordinatorAndProjectAvailable = SignalProducer.combineLatest(modelCoordinatorP.producer.filter { $0 != nil }, selectedProject.producer.filter { $0 != nil })
        modelCoordinatorAndProjectAvailable.startWithValues { [weak self] (modelCoordinator, project) in
            let goalProperty = modelCoordinator!.goalProperty(for: project!.id)
            self?.observeGoalProperty(goalProperty).reportImmediately()
            self?.goalViewController.goalProperty = goalProperty
            let reportProperty = modelCoordinator!.reportProperty(for: project!.id)
            self?.goalReportViewController.setGoalProperty(goalProperty, reportProperty: reportProperty)
        }
    }


    @discardableResult
    private func observeGoalProperty(_ goalProperty: Property<TimeGoal>) -> ObservedProperty<TimeGoal> {
        func goalDidChange(_ observedGoal: ObservedProperty<TimeGoal>?) {
            let goalExists = (observedGoal?.original?.value != nil)
            let controller = goalExists ? goalReportViewController : noGoalViewController
            displayController(controller, in: goalReportView)
        }
        
        func goalWasInvalidated() {
            goalDidChange(nil)
        }
        
        observedGoalProperty?.unobserve()
        let observed = ObservedProperty<TimeGoal>(original: goalProperty, valueObserver: goalDidChange, invalidationObserver: goalWasInvalidated)
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
            let projectId = selectedProject.value?.id else {
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
