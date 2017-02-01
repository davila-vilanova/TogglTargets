//
//  ProjectDetailsViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectDetailsViewController: NSViewController, ModelCoordinatorContaining {

    @IBOutlet weak var monthlyHoursGoalField: NSTextField!
    @IBOutlet weak var monthlyHoursGoalFormatter: NumberFormatter!
    @IBOutlet weak var workDaysPerWeekGoalField: NSTextField!
    @IBOutlet weak var workDaysPerWeekFormatter: NumberFormatter!

    var modelCoordinator: ModelCoordinator?
    private var observedGoalProperty: ObservedProperty<TimeGoal>?
    private var projectId: Int64?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    internal func onProjectSelected(projectId: Int64) {
        Swift.print("selected project with id=\(projectId)")
        self.projectId = projectId

        if let mc = modelCoordinator {
            let goalProperty = mc.goalPropertyForProjectId(projectId)
            Swift.print("Goal for project=\(goalProperty)")

            observedGoalProperty?.unobserve()
            observedGoalProperty =
                ObservedProperty<TimeGoal>(original: goalProperty,
                                           valueObserver: { [weak self] (goal) in
                                            self?.handleGoalValue(goal)
                    },
                                           invalidationObserver: { })
            handleGoalValue(goalProperty.value)
        }
    }

    @IBAction func monthlyHoursGoalEdited(_ sender: NSTextField) {
        if let parsedHours = monthlyHoursGoalFormatter.number(from: sender.stringValue) {
            observedGoalProperty?.original?.value?.hoursPerMonth = parsedHours.intValue
        } else {
            sender.stringValue = ""
        }
    }

    @IBAction func workDaysPerWeekEdited(_ sender: NSTextFieldCell) {
        if let parsedDays = workDaysPerWeekFormatter.number(from: sender.stringValue) {
            observedGoalProperty?.original?.value?.workDaysPerWeek = parsedDays.intValue
        } else {
            sender.stringValue = ""
        }
    }

    private func handleGoalValue(_ goal: TimeGoal?) {
        if let g = goal {
            displayGoal(goal: g)
        } else if let p = projectId {
            createGoal(projectId: p)
        }
    }

    private func displayGoal(goal: TimeGoal) {
        if let hours = goal.hoursPerMonth,
            let hoursString = monthlyHoursGoalFormatter.string(from: NSNumber(value: hours)) {
            monthlyHoursGoalField.stringValue = hoursString
        } else {
            monthlyHoursGoalField.stringValue = ""
        }
        if let days = goal.workDaysPerWeek,
            let daysString = workDaysPerWeekFormatter.string(from: NSNumber(value: days)) {
            workDaysPerWeekGoalField.stringValue = daysString
        } else {
            workDaysPerWeekGoalField.stringValue = ""
        }
    }

    private func createGoal(projectId: Int64) {
        var goal = TimeGoal(forProjectId: projectId)
        goal.hoursPerMonth = 25
        goal.workDaysPerWeek = 5
        modelCoordinator?.initializeGoal(goal)
    }
}
