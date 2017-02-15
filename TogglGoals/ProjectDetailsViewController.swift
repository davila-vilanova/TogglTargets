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
    @IBOutlet weak var projectName: NSTextField!

    var modelCoordinator: ModelCoordinator?
    private var observedGoalProperty: ObservedProperty<TimeGoal>?
    private var projectId: Int64?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    internal func onProjectSelected(project: Project) {
        let projectId = project.id

        if let name = project.name {
            projectName.stringValue = name
        } else {
            projectName.stringValue = "No name"
        }

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
            let hoursPerMonth = parsedHours.intValue
            createGoalIfNotExists(hoursPerMonth: hoursPerMonth)
            observedGoalProperty?.original?.value?.hoursPerMonth = hoursPerMonth
        } else {
            sender.stringValue = ""
        }
    }

    @IBAction func workDaysPerWeekEdited(_ sender: NSTextFieldCell) {
        if let parsedDays = workDaysPerWeekFormatter.number(from: sender.stringValue) {
            let daysPerWeek = parsedDays.intValue
            createGoalIfNotExists(daysPerWeek: daysPerWeek)
            observedGoalProperty?.original?.value?.workDaysPerWeek = daysPerWeek
        } else {
            sender.stringValue = ""
        }
    }

    private func handleGoalValue(_ goal: TimeGoal?) {
        displayGoal(goal: goal)
    }

    private func displayGoal(goal: TimeGoal?) {
        if let hours = goal?.hoursPerMonth,
            let hoursString = monthlyHoursGoalFormatter.string(from: NSNumber(value: hours)) {
            monthlyHoursGoalField.stringValue = hoursString
        } else {
            monthlyHoursGoalField.stringValue = ""
        }
        if let days = goal?.workDaysPerWeek,
            let daysString = workDaysPerWeekFormatter.string(from: NSNumber(value: days)) {
            workDaysPerWeekGoalField.stringValue = daysString
        } else {
            workDaysPerWeekGoalField.stringValue = ""
        }
    }

    private func createGoalIfNotExists(hoursPerMonth: Int = 0, daysPerWeek: Int = 0) {
        if self.observedGoalProperty?.original?.value == nil,
            let projectId = self.projectId {
            var goal = TimeGoal(forProjectId: projectId)
            goal.hoursPerMonth = hoursPerMonth
            goal.workDaysPerWeek = daysPerWeek
            modelCoordinator?.initializeGoal(goal)
        }
    }
}
