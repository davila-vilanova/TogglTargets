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
    @IBOutlet weak var weekWorkDaysControl: NSSegmentedControl!

    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var goalButton: NSButton!

    var modelCoordinator: ModelCoordinator?
    private var representedProject: Project?
    private var observedGoalProperty: ObservedProperty<TimeGoal>?
    private var observedReportProperty: ObservedProperty<TimeReport>?

    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }()

    private var segmentsToWeekdays = Dictionary<Int, Weekday>()
    private var weekdaysToSegments = Dictionary<Weekday, Int>()

    override func viewDidLoad() {
        super.viewDidLoad()

        populateWeekWorkDaysControl()
    }

    private func populateWeekWorkDaysControl() {
        let weekdaySymbols = calendar.veryShortWeekdaySymbols
        weekWorkDaysControl.segmentCount = weekdaySymbols.count

        let startFrom = Weekday.monday
        var dayIndex = startFrom.rawValue
        var segmentIndex = 0

        segmentsToWeekdays.removeAll()
        weekdaysToSegments.removeAll()

        func addSegment(_ day: Weekday) {
            let daySymbol = weekdaySymbols[day.rawValue]
            weekWorkDaysControl.setLabel(daySymbol, forSegment: segmentIndex)
            segmentsToWeekdays[segmentIndex] = day
            weekdaysToSegments[day] = segmentIndex
            segmentIndex += 1
        }

        while let day = Weekday(rawValue: dayIndex) {
            addSegment(day)
            dayIndex += 1
        }

        dayIndex = 0
        while let day = Weekday(rawValue: dayIndex), dayIndex < startFrom.rawValue {
            addSegment(day)
            dayIndex += 1
        }
    }

    internal func onProjectSelected(project: Project) {
        self.representedProject = project

        if let name = project.name {
            projectName.stringValue = name
        } else {
            projectName.stringValue = "No name"
        }

        if let mc = modelCoordinator {
            let goalProperty = mc.goalPropertyForProjectId(project.id)

            observedGoalProperty?.unobserve()
            observedGoalProperty = ObservedProperty<TimeGoal>(original: goalProperty, valueObserver: { [weak self] (goal) in self?.handleGoalValue(goal)}).reportImmediately()

            let reportProperty = mc.reportPropertyForProjectId(project.id)
            observedReportProperty?.unobserve()
            observedReportProperty = ObservedProperty<TimeReport>(original: reportProperty, valueObserver: { [weak self] (report) in self?.handleReportValue(report) }).reportImmediately()
        }
    }

    @IBAction func monthlyHoursGoalEdited(_ sender: NSTextField) {
        if let parsedHours = monthlyHoursGoalFormatter.number(from: sender.stringValue) {
            let hoursPerMonth = parsedHours.intValue
            observedGoalProperty?.original?.value?.hoursPerMonth = hoursPerMonth
        } else {
            sender.stringValue = ""
        }
    }

    @IBAction func weekWorkDaysEdited(_ sender: NSSegmentedControl) {
        var newSelection = WeekdaySelection()

        for (day, segmentIndex) in weekdaysToSegments {
            assert(segmentIndex < sender.segmentCount)
            if sender.isSelected(forSegment: segmentIndex) {
                newSelection.select(day)
            }
        }

        observedGoalProperty?.original?.value?.workWeekdays = newSelection
    }

    private func handleGoalValue(_ goal: TimeGoal?) {
        displayGoal(goal: goal)
    }

    private func handleReportValue(_ report: TimeReport?) {
//        print("new report value=\(report)");
    }

    private func displayGoal(goal optionalGoal: TimeGoal?) {
        func setEnabledState(_ goalExists: Bool) {
            goalButton.isEnabled = !goalExists
            monthlyHoursGoalField.isEnabled = goalExists
            weekWorkDaysControl.isEnabled = goalExists
        }

        if let goal = optionalGoal {

            setEnabledState(true)

            if let hoursString = monthlyHoursGoalFormatter.string(from: NSNumber(value: goal.hoursPerMonth)) {
                monthlyHoursGoalField.stringValue = hoursString
            } else {
                monthlyHoursGoalField.stringValue = ""
            }

            for (day, segmentIndex) in weekdaysToSegments {
                weekWorkDaysControl.setSelected(goal.workWeekdays.isSelected(day), forSegment: segmentIndex)
            }
        } else {
            setEnabledState(false)

            monthlyHoursGoalField.stringValue = ""
            for (_, segmentIndex) in weekdaysToSegments {
                weekWorkDaysControl.setSelected(false, forSegment: segmentIndex)
            }
        }
    }

    @IBAction func createGoal(_ sender: Any) {
        createGoalIfNotExists()
    }

    private func createGoalIfNotExists(hoursPerMonth: Int = 0,
                                       workWeekdays: WeekdaySelection = WeekdaySelection.exceptWeekend) {
        if self.observedGoalProperty?.original?.value == nil,
            let projectId = representedProject?.id {
            let goal = TimeGoal(forProjectId: projectId, hoursPerMonth: hoursPerMonth, workWeekdays: workWeekdays)
            modelCoordinator?.initializeGoal(goal)
        }
    }
}
