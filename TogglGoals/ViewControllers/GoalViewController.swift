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

class GoalViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: - Interface

    internal typealias Interface = (
        calendar: SignalProducer<Calendar, NoError>,
        goal: SignalProducer<TimeTarget?, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        userUpdates: BindingTarget<TimeTarget>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Output

    private var userUpdates = MutableProperty<TimeTarget?>(nil)


    // MARK: - Internal

    private var deleteConfirmed = MutableProperty(())


    // MARK: - Outlets

    @IBOutlet weak var hoursTargetLabel: NSTextField!
    @IBOutlet weak var hoursTargetField: NSTextField!
    @IBOutlet weak var hoursTargetStepper: NSStepper!
    @IBOutlet weak var periodDescriptionLabel: NSTextField!
    @IBOutlet weak var hoursTargetFormatter: NumberFormatter!
    @IBOutlet weak var activeWeekdaysLabel: NSTextField!
    @IBOutlet weak var activeWeekdaysControl: NSSegmentedControl!
    @IBOutlet weak var deleteGoalButton: NSButton!


    // MARK: - Wiring

    /// Populates the active weekdays control with short weekday symbols
    /// taken from the received Calendar values.
    private lazy var weekdaySegments = activeWeekdaysControl.reactive
        .makeBindingTarget(on: UIScheduler()) { (control: NSSegmentedControl, calendar: Calendar) in
            let displayDaySymbols = calendar.veryShortStandaloneWeekdaySymbols
            let toolTipDaySymbols = calendar.standaloneWeekdaySymbols
            let dayCount = displayDaySymbols.count
            assert(dayCount == Weekday.allDays.count)
            control.segmentCount = dayCount

            for dayIndex in 0..<dayCount {
                control.setLabel(displayDaySymbols[dayIndex], forSegment: dayIndex)
                if #available(OSX 10.13, *) {
                    control.setToolTip(toolTipDaySymbols[dayIndex], forSegment: dayIndex)
                }
            }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        deleteGoalButton.image!.isTemplate = true

        // Connect interface
        let calendar = lastBinding.producer.skipNil().map { $0.calendar }.flatten(.latest)
        let goal = lastBinding.producer.skipNil().map { $0.goal }.flatten(.latest)
        userUpdates.signal.skipNil().bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.userUpdates })

        // Populate controls that depend on calendar values
        weekdaySegments <~ calendar

        // Emits non nil goal values coming through the interface
        let nonNilGoal = goal.producer.skipNil()

        // Bind goal values to the values displayed in the controls
        hoursTargetField.reactive.text <~ nonNilGoal.map { $0.hoursTarget }
            .map(NSNumber.init)
            .map(hoursTargetFormatter.string(from:))
            .map { $0 ?? "" }

        hoursTargetStepper.reactive.integerValue <~ nonNilGoal.map { $0.hoursTarget }

        activeWeekdaysControl.reactive
            .makeBindingTarget(on: UIScheduler()) { $0.setSelected($1.0, forSegment: $1.1) }
            <~ Property(value: Weekday.allDaysOrdered).producer
                .sample(on: nonNilGoal.map { _ in () })
                .map(SignalProducer<Weekday, NoError>.init)
                .flatten(.latest)
                .withLatest(from: nonNilGoal.map { $0.workWeekdays })
                .map { ($1.isSelected($0), $0.indexInGregorianCalendarSymbolsArray) }

        // Bind period preference to period description
        periodDescriptionLabel.reactive.stringValue <~ lastBinding.producer.skipNil().map { $0.periodPreference }.flatten(.latest)
            .map {
                switch $0 {
                case .monthly: return NSLocalizedString("goal-controller.target-hours-period.month", comment: "month period description as it appears next to the target hours field in the goal VC")
                case .weekly: return NSLocalizedString("goal-controller.target-hours-period.week", comment: "week period description as it appears next to the target hours field in the goal VC")
                }
        }

        // Bind hours stepper buttons and hours target field
        hoursTargetField.reactive.integerValue <~ hoursTargetStepper.reactive.integerValues
        hoursTargetStepper.reactive.integerValue <~ hoursTargetField.reactive.integerValues

        // Bind UI to output

        let textFieldValues = hoursTargetField.reactive.stringValues
            .filterMap { [weak formatter = hoursTargetFormatter] (text) -> HoursTargetType? in
                formatter?.number(from: text)?.intValue
        }
        let stepperValues = hoursTargetStepper.reactive.integerValues

        let goalFromEditedHours = Signal.merge(textFieldValues, stepperValues)
            .producer
            .withLatest(from: nonNilGoal)
            .map { TimeTarget(for: $1.projectId, hoursTarget: $0, workWeekdays: $1.workWeekdays) }

        
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
            .map { TimeTarget(for: $1.projectId, hoursTarget: $1.hoursTarget, workWeekdays: $0) }

        let editedGoal = SignalProducer.merge(goalFromEditedHours,
                                              goalFromEditedActiveWeekdays)

        userUpdates <~ editedGoal.map { Optional($0) }

        // Enable controls only if goal exists
        let goalExists = goal.producer.map { $0 != nil }.skipRepeats()
        for control in [hoursTargetLabel, hoursTargetField, activeWeekdaysLabel, activeWeekdaysControl, deleteGoalButton] as [NSControl] {
            control.reactive.isEnabled <~ goalExists
        }

        reactive.makeBindingTarget { (goalVC, _: Void) in
            goalVC.try(toPerform: #selector(GoalCreatingDeleting.deleteGoal(_:)), with: goalVC)
        } <~ deleteConfirmed.signal
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let deleteGoalController = segue.destinationController as? DeleteGoalPopup {
            deleteGoalController <~ SignalProducer(value: deleteConfirmed.bindingTarget)
        }
    }
    
    
    // MARK: - Onboarding

    var onboardingTargetViews: [OnboardingStepIdentifier : SignalProducer<NSView, NoError>] {
        let hoursTargetField = viewDidLoadProducer
            .map { [unowned self] _ in self.hoursTargetField }
            .skipNil()
        
        let targetHoursEdited = hoursTargetField.map { $0.reactive.stringValues.map { _ in () } }.flatten(.concat)
        let targetHoursView = hoursTargetField
            .map { $0 as NSView }
            .concat(SignalProducer.never)
            .take(until: targetHoursEdited)
        
        let activeWeekdaysControl = viewDidLoadProducer
            .map { [unowned self] _ in self.activeWeekdaysControl }
            .skipNil()
        
        let activeWeekdaysEdited = activeWeekdaysControl.map { $0.reactive.selectedSegmentIndexes.map { _ in () } }.flatten(.concat)

        let workWeekdaysView = activeWeekdaysControl
            .map { $0 as NSView }
            .concat(SignalProducer.never)
            .take(until: activeWeekdaysEdited)

        return [.setTargetHours : targetHoursView,
                .setWorkWeekdays : workWeekdaysView]
    }
}

// MARK: -

class DeleteGoalPopup: NSViewController, BindingTargetProvider {
    internal typealias Interface = BindingTarget<Void>

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    @IBOutlet weak var confirmDeletionButton: NSButton!
    @IBOutlet weak var dismissControllerButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        let confirmDeletionAction = Action<Void, Void, NoError> {
            SignalProducer(value: ())
        }

        let dismissAction = Action<Void, Void, NoError> {
            SignalProducer(value: ())
        }

        let dismiss = reactive.makeBindingTarget { (popUpController, _: Void) in
            popUpController.dismiss(popUpController)
        }
        dismiss <~ confirmDeletionAction.values
        dismiss <~ dismissAction.values

        confirmDeletionAction.values.bindOnlyToLatest(lastBinding.producer.skipNil())

        confirmDeletionButton.reactive.pressed = CocoaAction(confirmDeletionAction)
        dismissControllerButton.reactive.pressed = CocoaAction(dismissAction)
    }
}

// MARK: -

class NoGoalViewController: NSViewController, OnboardingTargetViewsProvider {
    @IBOutlet weak var createGoalButton: NSButton!

    var onboardingTargetViews: [OnboardingStepIdentifier : SignalProducer<NSView, NoError>] {
        let createGoalButtonPressed = Action<Void, Void, NoError> {
            SignalProducer(value: ())
        }

        let viewDidAppearProducer = reactive.trigger(for: #selector(viewDidAppear)).producer.take(first: 1)

        let goalCreationViewProducer = viewDidAppearProducer
            .on(value: { [unowned self] in
                self.createGoalButton.reactive.pressed = CocoaAction(createGoalButtonPressed)
            })
            .map { [unowned self] in self.createGoalButton as NSView }

        let goalCreationView = goalCreationViewProducer.concat(SignalProducer.never).take(until: createGoalButtonPressed.values)
        
        return [.createGoal : goalCreationView]
    }
}
