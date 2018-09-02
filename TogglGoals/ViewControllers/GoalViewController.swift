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



    // MARK: - Internal

    private var deleteConfirmed = MutableProperty(())


    // MARK: - Outlets

    @IBOutlet weak var hoursTargetLabel: NSTextField!
    @IBOutlet weak var hoursTargetField: NSTextField!
    @IBOutlet weak var hoursTargetFormatter: NumberFormatter!
    @IBOutlet weak var activeWeekdaysLabel: NSTextField!
    @IBOutlet weak var activeWeekdaysControl: NSSegmentedControl!
    @IBOutlet weak var deleteGoalButton: NSButton!


    // MARK: - Wiring

    /// Populates the active weekdays control with short weekday symbols
    /// taken from the received Calendar values.
    private lazy var weekdaySegments = activeWeekdaysControl.reactive
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

        deleteGoalButton.image!.isTemplate = true

        // Connect interface
        let calendar = lastBinding.producer.skipNil().map { $0.calendar }.flatten(.latest)
        let goal = lastBinding.producer.skipNil().map { $0.goal }.flatten(.latest)
        userUpdates.signal.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.userUpdates })

        // Populate controls that depend on calendar values
        weekdaySegments <~ calendar

        // Emits non nil goal values coming through the interface
        let nonNilGoal = goal.producer.skipNil()

        // Bind goal values to the values displayed in the controls
        hoursTargetField.reactive.text <~ nonNilGoal.map { $0.hoursTarget }
            .map(NSNumber.init)
            .map(hoursTargetFormatter.string(from:))
            .map { $0 ?? "" }

        activeWeekdaysControl.reactive
            .makeBindingTarget(on: UIScheduler()) { $0.setSelected($1.0, forSegment: $1.1) }
            <~ Property(value: Weekday.allDaysOrdered).producer
                .sample(on: nonNilGoal.map { _ in () })
                .map(SignalProducer<Weekday, NoError>.init)
                .flatten(.latest)
                .withLatest(from: nonNilGoal.map { $0.workWeekdays })
                .map { ($1.isSelected($0), $0.indexInGregorianCalendarSymbolsArray) }

        // Bind UI to output
        let goalFromEditedHours = hoursTargetField.reactive.stringValues
            .map { [weak formatter = hoursTargetFormatter] (text) -> HoursTargetType? in
                formatter?.number(from: text)?.intValue
            }
            .skipNil()
            .producer
            .withLatest(from: nonNilGoal)
            .map { Goal(for: $1.projectId, hoursTarget: $0, workWeekdays: $1.workWeekdays) }

        let goalFromEditedActiveWeekdays = activeWeekdaysControl.reactive.selectedSegmentIndexes
            .map { [weak activeWeekdaysControl] (_) -> WeekdaySelection? in
                guard let control = activeWeekdaysControl else {
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

        userUpdates <~ SignalProducer.merge(editedGoal.map { Optional($0) }, deleteConfirmed.signal.map { nil as Goal? }.producer.logEvents())

        // Enable controls only if goal exists
        let goalExists = goal.producer.map { $0 != nil }.skipRepeats()
        for control in [hoursTargetLabel, hoursTargetField, activeWeekdaysLabel, activeWeekdaysControl, deleteGoalButton] as [NSControl] {
            control.reactive.isEnabled <~ goalExists
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let deleteGoalController = segue.destinationController as? DeleteGoalPopup {
            deleteGoalController <~ SignalProducer(value: deleteConfirmed.bindingTarget)
        }
    }
}

class DeleteGoalPopup: NSViewController, BindingTargetProvider {
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var dismissButton: NSButton!

    internal typealias Interface = BindingTarget<Void>

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    override func viewDidLoad() {
        super.viewDidLoad()
        let sendDeleteAction = Action<Void, Void, NoError> { SignalProducer(value: ()) }

        deleteButton.reactive.makeBindingTarget {
            $0.reactive.pressed = CocoaAction(sendDeleteAction)
            $1 <~ sendDeleteAction.values
        } <~ lastBinding.producer.skipNil()

        reactive.makeBindingTarget { (controller, _) in
            controller.dismiss(controller.deleteButton)
        } <~ sendDeleteAction.values

        dismissButton.reactive.pressed = CocoaAction(Action<Void, Void, NoError> { [unowned self] in
            self.dismiss(self.dismissButton)
            return SignalProducer.empty
        })
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
