//
//  GoalViewController.swift
//  TogglGoals
//
//  Created by David Davila on 26.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

class GoalViewController: NSViewController {

    // MARK: Exposed targets and source

    internal var goal: BindingTarget<Goal?> { return _goal.bindingTarget }
    internal var userUpdates: Signal<Goal?, NoError> { return _userUpdates.output }

    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }


    // MARK: - Backing properties

    private let _goal = MutableProperty<Goal?>(nil)
    private var _userUpdates = Signal<Goal?, NoError>.pipe()
    private var _calendar = MutableProperty<Calendar?>(nil)


    // MARK: - Outlets

    @IBOutlet weak var monthlyHoursGoalField: NSTextField!
    @IBOutlet weak var monthlyHoursGoalFormatter: NumberFormatter!
    @IBOutlet weak var weekWorkDaysControl: NSSegmentedControl!
    @IBOutlet weak var deleteGoalButton: NSButton!


    // MARK: -

    private var segmentsToWeekdays = Dictionary<Int, Weekday>()
    private var weekdaysToSegments = Dictionary<Weekday, Int>()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up view
        _calendar.producer.skipNil().startWithValues { [unowned self] (cal) in
            self.populateWeekWorkDaysControl(calendar: cal)
        }

        // Bind input to UI
        let goalExists = _goal.producer.map { $0 != nil }.skipRepeats()
        monthlyHoursGoalField.reactive.isEnabled <~ goalExists
        weekWorkDaysControl.reactive.isEnabled <~ goalExists
        deleteGoalButton.reactive.isEnabled <~ goalExists
        goalExists.filter { $0 == false }.producer.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            self.setSelectedWeekDays(nil)
        }

        _goal.producer.skipNil().skipRepeats { $0 == $1 }.observe(on: UIScheduler()).startWithValues { [unowned self] goal in
            self.setSelectedWeekDays(goal.workWeekdays)
        }

        monthlyHoursGoalField.reactive.text <~ _goal.map { [monthlyHoursGoalFormatter] goal in
            if let formatter = monthlyHoursGoalFormatter,
                let goal = goal,
                let hoursString = formatter.string(from: NSNumber(value: goal.hoursPerMonth)) {
                return hoursString
            } else {
                return "---"
            }
        }

        // Bind UI to output (and to internal state)
        weekWorkDaysControl.reactive.selectedSegmentIndexes.observeValues { [unowned self] _ in
            var newSelection = WeekdaySelection()

            for (day, segmentIndex) in self.weekdaysToSegments {
                assert(segmentIndex < self.weekWorkDaysControl.segmentCount)
                if self.weekWorkDaysControl.isSelected(forSegment: segmentIndex) {
                    newSelection.select(day)
                }
            }
            guard var goalValue = self._goal.value else {
                return
            }
            goalValue.workWeekdays = newSelection
            self._goal.value = goalValue
            self._userUpdates.input.send(value: goalValue)
        }


        monthlyHoursGoalField.reactive.stringValues.observeValues { [unowned self] (text) in
            if let parsedHours = self.monthlyHoursGoalFormatter.number(from: text) {

                guard var goalValue = self._goal.value else {
                    return
                }
                goalValue.hoursPerMonth = parsedHours.intValue
                self._goal.value = goalValue
                self._userUpdates.input.send(value: goalValue)
            }
        }
    }

    private func populateWeekWorkDaysControl(calendar: Calendar) {
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

    private func setSelectedWeekDays(_ selection: WeekdaySelection?) {
        for (day, segmentIndex) in weekdaysToSegments {
            weekWorkDaysControl.setSelected(selection?.isSelected(day) ?? false, forSegment: segmentIndex)
        }
    }

    @IBAction func deleteGoal(_ sender: Any) {
        _goal.value = nil
        _userUpdates.input.send(value: _goal.value)
    }
}

// MARK: -

class NoGoalViewController: NSViewController {

    // MARK: Exposed target and source

    var projectId: BindingTarget<Int64> { return _projectId.deoptionalizedBindingTarget }
    var goalCreated: Signal<Goal, NoError> { return _goalCreated.output }


    // MARK: - Private

    private let _projectId = MutableProperty<Int64?>(nil)
    private let _goalCreated = Signal<Goal, NoError>.pipe()

    private var createGoalAction: Action<Void, Goal, NoError>!


    // MARK: - Outlet

    @IBOutlet weak var createGoalButton: NSButton!


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        createGoalAction = Action<Void, Goal, NoError>(unwrapping: _projectId, execute: { (projectIdValue: Int64) -> SignalProducer<Goal, NoError> in
            return SignalProducer<Goal, NoError> { (sink: Signal<Goal, NoError>.Observer, disposable: Lifetime) in
                sink.send(value: Goal(forProjectId: projectIdValue, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend))
                sink.sendCompleted()
            }
        })

        self.createGoalButton.reactive.pressed = CocoaAction<NSButton>(createGoalAction)
        
        createGoalAction.values.observe(_goalCreated.input)
    }
}
