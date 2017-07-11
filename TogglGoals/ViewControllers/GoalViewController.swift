//
//  GoalViewController.swift
//  TogglGoals
//
//  Created by David Davila on 26.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

class GoalViewController: NSViewController {
    weak var delegate: GoalViewControllerDelegate?
    
    private var segmentsToWeekdays = Dictionary<Int, Weekday>()
    private var weekdaysToSegments = Dictionary<Weekday, Int>()

    var calendar: Calendar!

    var strategyComputer: StrategyComputer!
    
    private var observedGoal: ObservedProperty<TimeGoal?>?

    var goalProperty: Property<TimeGoal?>? {
        willSet {
            if let observedGoal = self.observedGoal {
                observedGoal.unobserve()
                self.observedGoal = nil
            }
        }
        didSet {
            guard let goalProperty = self.goalProperty else {
                resetAndDisable()
                return
            }
            observedGoal = ObservedProperty<TimeGoal?>(original: goalProperty, valueObserver: goalDidChange, invalidationObserver: resetAndDisable).reportImmediately()
        }
    }

    @IBOutlet weak var monthlyHoursGoalField: NSTextField!
    @IBOutlet weak var monthlyHoursGoalFormatter: NumberFormatter!
    @IBOutlet weak var weekWorkDaysControl: NSSegmentedControl!
    @IBOutlet weak var deleteGoalButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        populateWeekWorkDaysControl()
    }
    
    private func populateWeekWorkDaysControl() {
        guard let calendar = self.calendar else {
            return
        }
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

    private func goalDidChange(observedGoal: ObservedProperty<TimeGoal?>) {
        guard let goal = observedGoal.original?.value else {
            resetAndDisable()
            return
        }
        monthlyHoursGoalField.isEnabled = true
        weekWorkDaysControl.isEnabled = true
        deleteGoalButton.isHidden = false
        
        if let hoursString = monthlyHoursGoalFormatter.string(from: NSNumber(value: goal.hoursPerMonth)) {
            monthlyHoursGoalField.stringValue = hoursString
        } else {
            monthlyHoursGoalField.stringValue = ""
        }
        
        for (day, segmentIndex) in weekdaysToSegments {
            weekWorkDaysControl.setSelected(goal.workWeekdays.isSelected(day), forSegment: segmentIndex)
        }
    }
    
    private func resetAndDisable() {
        monthlyHoursGoalField.isEnabled = false
        weekWorkDaysControl.isEnabled = false
        monthlyHoursGoalField.stringValue = ""
        for (_, segmentIndex) in weekdaysToSegments {
            weekWorkDaysControl.setSelected(false, forSegment: segmentIndex)
        }
        deleteGoalButton.isHidden = true
    }
    
    @IBAction func monthlyHoursGoalEdited(_ sender: NSTextField) {
        if let parsedHours = monthlyHoursGoalFormatter.number(from: sender.stringValue) {
            let hoursPerMonth = parsedHours.intValue
            observedGoal?.original?.value?.hoursPerMonth = hoursPerMonth
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
        
        observedGoal?.original?.value?.workWeekdays = newSelection
    }
    
    @IBAction func deleteGoal(_ sender: Any) {
        if let d = delegate {
            d.onDeleteGoalAction()
        }
    }
}

class NoGoalViewController: NSViewController {
    weak var delegate: NoGoalViewControllerDelegate?
    
    @IBAction func createGoal(_ sender: Any) {
        if let d = delegate {
            d.onCreateGoalAction()
        }
    }
}

protocol NoGoalViewControllerDelegate: NSObjectProtocol {
    func onCreateGoalAction()
}

protocol GoalViewControllerDelegate: NSObjectProtocol {
    func onDeleteGoalAction()
}
