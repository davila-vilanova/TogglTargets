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

class GoalViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        calendar: SignalProducer<Calendar, NoError>,
        goal: SignalProducer<Goal?, NoError>,
        userUpdates: BindingTarget<Goal?>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Output

    private var userUpdates = MutableProperty<Goal?>(nil)


    // MARK: - Outlets

    @IBOutlet weak var hoursGoalField: NSTextField!
    @IBOutlet weak var hoursGoalFormatter: NumberFormatter!
    @IBOutlet weak var weekWorkdaysControl: NSSegmentedControl!
    @IBOutlet weak var deleteGoalButton: NSButton!


    // MARK: - Wiring

    private let (lifetime, token) = Lifetime.make()

    /// Populates the active weekdays control with short weekday symbols
    /// taken from the received Calendar values.
    private lazy var weekdaySegments = weekWorkdaysControl.reactive
        .makeBindingTarget(on: UIScheduler()) { (control: NSSegmentedControl, calendar: Calendar) in
            let daySymbols = calendar.veryShortWeekdaySymbols
            let dayCount = daySymbols.count
            assert(dayCount == Weekday.allDays.count)
            control.segmentCount = dayCount

            for dayIndex in 0..<dayCount {
                control.setLabel(daySymbols[dayIndex], forSegment: dayIndex)
            }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Connect interface
        let calendar = lastBinding.producer.skipNil().map { $0.calendar }.flatten(.latest)
        let goal = lastBinding.producer.skipNil().map { $0.goal }.flatten(.latest)
        userUpdates.signal.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.userUpdates })

        // Populate controls that depend on calendar values
        weekdaySegments <~ calendar

        // Emits non nil goal values coming through the interface
        let nonNilGoal = goal.producer.skipNil()

        // Enable controls only if goal exists
        let goalExists = goal.producer.map { $0 != nil }.skipRepeats()
        for control in [hoursGoalField, weekWorkdaysControl, deleteGoalButton] as [NSControl] {
            control.reactive.isEnabled <~ goalExists
        }

        // Bind goal values to the values displayed in the controls
        hoursGoalField.reactive.text <~ nonNilGoal.map { $0.hoursTarget }
            .map(NSNumber.init)
            .map(hoursGoalFormatter.string(from:))
            .map { $0 ?? "" }

        weekWorkdaysControl.reactive
            .makeBindingTarget(on: UIScheduler()) { $0.setSelected($1.0, forSegment: $1.1) }
            <~ Property(value: Weekday.allDaysOrdered).producer
                .sample(on: nonNilGoal.map { _ in () })
                .map(SignalProducer<Weekday, NoError>.init)
                .flatten(.latest)
                .withLatest(from: nonNilGoal.map { $0.workWeekdays })
                .map { ($1.isSelected($0), $0.indexInGregorianCalendarSymbolsArray) }

        // Bind UI to output
        let goalFromEditedHours = hoursGoalField.reactive.stringValues
            .map { [weak formatter = hoursGoalFormatter] (text) -> HoursTargetType? in
                formatter?.number(from: text)?.intValue
            }
            .skipNil()
            .producer
            .withLatest(from: nonNilGoal)
            .map { Goal(for: $1.projectId, hoursTarget: $0, workWeekdays: $1.workWeekdays) }

        let goalFromEditedActiveWeekdays = weekWorkdaysControl.reactive.selectedSegmentIndexes
            .map { [weak weekWorkdaysControl] (_) -> WeekdaySelection? in
                guard let control = weekWorkdaysControl else {
                    return nil
                }
                var newSelection = WeekdaySelection.empty

                for day in Weekday.allDaysOrdered {
                    if control.isSelected(forSegment: day.indexInGregorianCalendarSymbolsArray) {
                        newSelection.select(day)
                    }
                }

                return newSelection
            }.skipNil()
            .producer
            .withLatest(from: nonNilGoal)
            .map { Goal(for: $1.projectId, hoursTarget: $1.hoursTarget, workWeekdays: $0) }

        let editedGoal = SignalProducer.merge(goalFromEditedHours,
                                              goalFromEditedActiveWeekdays)

        let deleteGoal = Action<Void, Void, NoError> { SignalProducer(value: ()) }
        deleteGoalButton.reactive.pressed = CocoaAction(deleteGoal)

        let deletedGoal = deleteGoal.values.map { nil as Goal? }.producer

        userUpdates <~ SignalProducer.merge(editedGoal.map { Optional($0) }, deletedGoal)
    }
}


// MARK: -

class NoGoalViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        projectId: SignalProducer<ProjectID, NoError>,
        goalCreated: BindingTarget<Goal>
    )

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Private

    private let projectId = MutableProperty<ProjectID?>(nil)
    private let goalCreatedPipe = Signal<Goal, NoError>.pipe()

    private var createGoalAction: Action<Void, Goal, NoError>!


    // MARK: - Outlet

    @IBOutlet weak var createGoalButton: NSButton!


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        projectId <~ lastBinding.latestOutput { $0.projectId }
        goalCreatedPipe.output.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.goalCreated })

        createGoalAction = Action<Void, Goal, NoError>(unwrapping: projectId) {
            SignalProducer(value: Goal(for: $0, hoursTarget: 10, workWeekdays: WeekdaySelection.exceptWeekend))
        }

        createGoalButton.reactive.pressed = CocoaAction<NSButton>(createGoalAction)
        createGoalAction.values.observe(goalCreatedPipe.input)
    }
}
