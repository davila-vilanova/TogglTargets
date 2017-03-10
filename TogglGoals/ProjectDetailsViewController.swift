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

    @IBOutlet weak var monthNameLabel: NSTextField!
    @IBOutlet weak var totalWorkdaysLabel: NSTextField!
    @IBOutlet weak var remainingFullWorkdaysLabel: NSTextField!
    @IBOutlet weak var hoursWorkedLabel: NSTextField!
    @IBOutlet weak var hoursLeftLabel: NSTextField!

    @IBOutlet weak var workDaysProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var workHoursProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var totalHoursStrategyLabel: NSTextField!
    @IBOutlet weak var hoursPerDayLabel: NSTextField!
    @IBOutlet weak var baselineDifferentialLabel: NSTextField!

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()

    private lazy var percentFormatter: NumberFormatter = {
        var f = NumberFormatter()
        f.numberStyle = .percent
        return f
    }()

    var modelCoordinator: ModelCoordinator?
    private var representedProject: Project?
    private var observedGoalProperty: ObservedProperty<TimeGoal>?
    private var observedReportProperty: ObservedProperty<TimeReport>?

    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }()

    private var segmentsToWeekdays = Dictionary<Int, Weekday>()
    private var weekdaysToSegments = Dictionary<Weekday, Int>()
    private var strategyComputer = StrategyComputer(calendar: Calendar(identifier: .iso8601), now: Date())

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
            observedGoalProperty = ObservedProperty<TimeGoal>(original: goalProperty, valueObserver: { [weak self] (goal) in self?.handleGoalValue(goal)})
            observedGoalProperty?.reportImmediately()

            let reportProperty = mc.reportPropertyForProjectId(project.id)
            observedReportProperty?.unobserve()
            observedReportProperty = ObservedProperty<TimeReport>(original: reportProperty, valueObserver: { [weak self] (report) in self?.handleReportValue(report) })
            observedReportProperty?.reportImmediately()
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
        updateStrategy()
    }

    private func handleReportValue(_ report: TimeReport?) {
        updateStrategy()
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

    @IBAction func computeStrategyFromToday(_ sender: NSMenuItem) {
        strategyComputer.computationMode = .fromToday
        updateStrategy()
    }


    @IBAction func computeStrategyFromNextWorkDay(_ sender: NSMenuItem) {
        strategyComputer.computationMode = .fromNextWorkDay
        updateStrategy()
    }

    private func updateStrategy() {
        guard let goal = observedGoalProperty?.original?.value,
            let report = observedReportProperty?.original?.value else {
                return
        }
        strategyComputer.goal = goal
        strategyComputer.report = report

        monthNameLabel.stringValue = "TBD"

        totalWorkdaysLabel.integerValue = strategyComputer.totalWorkdays
        remainingFullWorkdaysLabel.integerValue = strategyComputer.remainingFullWorkdays

        workDaysProgressIndicator.maxValue = Double(strategyComputer.totalWorkdays)
        workDaysProgressIndicator.doubleValue = Double(strategyComputer.totalWorkdays - strategyComputer.remainingFullWorkdays)
        workHoursProgressIndicator.maxValue = strategyComputer.timeGoal
        workHoursProgressIndicator.doubleValue = strategyComputer.workedTime

        hoursWorkedLabel.stringValue = timeFormatter.string(from: strategyComputer.workedTime)!
        hoursLeftLabel.stringValue = timeFormatter.string(from: strategyComputer.remainingTimeToGoal)!
        totalHoursStrategyLabel.stringValue = timeFormatter.string(from: strategyComputer.timeGoal)!
        hoursPerDayLabel.stringValue = timeFormatter.string(from: strategyComputer.dayBaselineAdjustedToProgress)!


        let dayBaseline = timeFormatter.string(from: strategyComputer.dayBaseline)!
        let dayBaselineDifferential = strategyComputer.dayBaselineDifferential
        let absoluteBaselineDifferential = Double.abs(dayBaselineDifferential)

        let baselineDifferentialText: String

        if absoluteBaselineDifferential < 0.01 {
            baselineDifferentialText = "That prety much matches your baseline of \(dayBaseline)"
        } else {
            let formattedBaselineDifferential = percentFormatter.string(from: NSNumber(value: Double.abs(dayBaselineDifferential)))!
            if dayBaselineDifferential > 0 {
                baselineDifferentialText = "That is \(formattedBaselineDifferential) more than your baseline of \(dayBaseline)"
            } else {
                baselineDifferentialText = "That is \(formattedBaselineDifferential) less than your baseline of \(dayBaseline)"
            }
        }

        baselineDifferentialLabel.stringValue = baselineDifferentialText
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
