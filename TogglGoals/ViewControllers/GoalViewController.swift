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

    // MARK: - Input

    internal func connectInputs(goal: SignalProducer<Goal?, NoError>,
                                calendar: SignalProducer<Calendar, NoError>) {
        enforceOnce(for: "GoalViewController.connectInputs()") {
            self.didLoadViewProperty.firstTrue.startWithValues {
                self.goal <~ goal
                self.calendar <~ calendar
            }
        }
    }

    // MARK: - Output

    internal var userUpdates: Signal<Goal?, NoError> { return _userUpdates.output }
    private var _userUpdates = Signal<Goal?, NoError>.pipe()


    // MARK: - Backing properties

    private let goal = MutableProperty<Goal?>(nil)
    private var calendar = MutableProperty<Calendar?>(nil)


    // MARK: - Outlets

    @IBOutlet weak var monthlyHoursGoalField: NSTextField!
    @IBOutlet weak var monthlyHoursGoalFormatter: NumberFormatter!
    @IBOutlet weak var weekWorkdaysControl: NSSegmentedControl!
    @IBOutlet weak var deleteGoalButton: NSButton!


    // MARK: -

    private let didLoadViewProperty = MutableProperty(false)

    private var segmentsToWeekdays = Dictionary<Int, Weekday>()
    private var weekdaysToSegments = Dictionary<Weekday, Int>()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up view
        calendar.producer.skipNil().observe(on: UIScheduler()).startWithValues { [unowned self] (cal) in
            self.populateWeekWorkDaysControl(calendar: cal)
        }

        // Bind input to UI
        let goalExists = goal.producer.map { $0 != nil }.skipRepeats()
        monthlyHoursGoalField.reactive.isEnabled <~ goalExists
        weekWorkdaysControl.reactive.isEnabled <~ goalExists
        deleteGoalButton.reactive.isEnabled <~ goalExists

        selectedWeekdaySegments <~ goal.map { $0?.workWeekdays }.producer
            .skipRepeats { $0 == $1 }
            .throttle(while: isWeekWorkdayControlPopulated.negate(), on: UIScheduler())

        monthlyHoursGoalField.reactive.text <~ goal.map { [monthlyHoursGoalFormatter] goal in
            if let formatter = monthlyHoursGoalFormatter,
                let goal = goal,
                let hoursString = formatter.string(from: NSNumber(value: goal.hoursPerMonth)) {
                return hoursString
            } else {
                return "---"
            }
        }

        // Bind UI to output (and to internal state)
        weekWorkdaysControl.reactive.selectedSegmentIndexes.observeValues { [unowned self] _ in
            var newSelection = WeekdaySelection.empty

            for (day, segmentIndex) in self.weekdaysToSegments {
                assert(segmentIndex < self.weekWorkdaysControl.segmentCount)
                if self.weekWorkdaysControl.isSelected(forSegment: segmentIndex) {
                    newSelection.select(day)
                }
            }
            guard var goalValue = self.goal.value else {
                return
            }
            goalValue.workWeekdays = newSelection
            self.goal.value = goalValue
            self._userUpdates.input.send(value: goalValue)
        }


        monthlyHoursGoalField.reactive.stringValues.observeValues { [unowned self] (text) in
            if let parsedHours = self.monthlyHoursGoalFormatter.number(from: text) {

                guard var goalValue = self.goal.value else {
                    return
                }
                goalValue.hoursPerMonth = parsedHours.intValue
                self.goal.value = goalValue
                self._userUpdates.input.send(value: goalValue)
            }
        }

        didLoadViewProperty.value = true
    }

    private let isWeekWorkdayControlPopulated = MutableProperty(false)
    private func populateWeekWorkDaysControl(calendar: Calendar) {
        let weekdaySymbols = calendar.veryShortWeekdaySymbols
        weekWorkdaysControl.segmentCount = weekdaySymbols.count

        let startFrom = Weekday.monday
        var dayIndex = startFrom.rawValue
        var segmentIndex = 0

        segmentsToWeekdays.removeAll()
        weekdaysToSegments.removeAll()

        func addSegment(_ day: Weekday) {
            let daySymbol = weekdaySymbols[day.rawValue]
            weekWorkdaysControl.setLabel(daySymbol, forSegment: segmentIndex)
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
        isWeekWorkdayControlPopulated.value = true
    }

    private let (lifetime, token) = Lifetime.make()
    private lazy var selectedWeekdaySegments = BindingTarget<WeekdaySelection?>(on: UIScheduler(), lifetime: lifetime) { [weak self] in
        guard let _self = self else {
            return
        }
        for (day, segmentIndex) in _self.weekdaysToSegments {
            _self.weekWorkdaysControl.setSelected($0?.isSelected(day) ?? false, forSegment: segmentIndex)
        }
    }

    @IBAction func deleteGoal(_ sender: Any) {
        goal.value = nil
        _userUpdates.input.send(value: goal.value)
    }
}

// MARK: -

class NoGoalViewController: NSViewController {

    // MARK: Inputs

    internal func connectInputs(projectId: SignalProducer<ProjectID, NoError>) {
        enforceOnce(for: "NoGoalViewController.connectInputs()") {
            self.projectId <~ projectId
        }
    }


    // MARK: - Outputs

    var goalCreated: Signal<Goal, NoError> { return goalCreatedPipe.output }


    // MARK: - Private

    private let projectId = MutableProperty<Int64?>(nil)
    private let goalCreatedPipe = Signal<Goal, NoError>.pipe()

    private var createGoalAction: Action<Void, Goal, NoError>!


    // MARK: - Outlet

    @IBOutlet weak var createGoalButton: NSButton!


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        createGoalAction = Action<Void, Goal, NoError>(unwrapping: projectId) {
            SignalProducer(value: Goal(forProjectId: $0, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend))
        }

        createGoalButton.reactive.pressed = CocoaAction<NSButton>(createGoalAction)
        createGoalAction.values.observe(goalCreatedPipe.input)
    }
}
