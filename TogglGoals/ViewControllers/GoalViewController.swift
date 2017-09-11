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

    // MARK: Interface

    internal var goal: BindingTarget<TimeGoal?> { return _goal.bindingTarget }
    internal var userUpdates: Signal<TimeGoal?, NoError> { return _userUpdates.output }


    // MARK: Private

    private let _goal = MutableProperty<TimeGoal?>(nil)
    private var _userUpdates = Signal<TimeGoal?, NoError>.pipe()

    private var segmentsToWeekdays = Dictionary<Int, Weekday>()
    private var weekdaysToSegments = Dictionary<Weekday, Int>()

    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }()


    // MARK: - Outlets

    @IBOutlet weak var monthlyHoursGoalField: NSTextField!
    @IBOutlet weak var monthlyHoursGoalFormatter: NumberFormatter!
    @IBOutlet weak var weekWorkDaysControl: NSSegmentedControl!
    @IBOutlet weak var deleteGoalButton: NSButton!


    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up view
        populateWeekWorkDaysControl()


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
            self._goal.value?.workWeekdays = newSelection
            self._userUpdates.input.send(value: self._goal.value)
        }


        monthlyHoursGoalField.reactive.stringValues.observeValues { [unowned self] (text) in
            if let parsedHours = self.monthlyHoursGoalFormatter.number(from: text) {
                self._goal.value?.hoursPerMonth = parsedHours.intValue
                self._userUpdates.input.send(value: self._goal.value)
            }
        }
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

class NoGoalViewController: NSViewController {
    @IBOutlet weak var createGoalButton: NSButton!

    var goalCreated: Signal<TimeGoal, NoError> { return _goalCreated.output }

    private let _goalCreated = Signal<TimeGoal, NoError>.pipe()

    private var createGoalAction: Action<Void, TimeGoal, NoError>!

    var projectId: BindingTarget<Int64?> { return _projectId.bindingTarget }

    private let _projectId = MutableProperty<Int64?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        createGoalAction = Action<Void, TimeGoal, NoError>(unwrapping: _projectId, execute: { (projectIdValue: Int64) -> SignalProducer<TimeGoal, NoError> in
            return SignalProducer<TimeGoal, NoError> { (sink: Signal<TimeGoal, NoError>.Observer, disposable: Lifetime) in
                sink.send(value: TimeGoal(forProjectId: projectIdValue, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend))
                sink.sendCompleted()
            }
        })

        self.createGoalButton.reactive.pressed = CocoaAction<NSButton>(createGoalAction)
        
        createGoalAction.values.observe(_goalCreated.input)
    }
}
