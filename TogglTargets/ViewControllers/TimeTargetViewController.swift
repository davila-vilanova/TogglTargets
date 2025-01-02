//
//  TimeTargetViewController.swift
//  TogglTargets
//
//  Created by David Davila on 26.05.17.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class TimeTargetViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: - Interface

    internal typealias Interface = (
        calendar: SignalProducer<Calendar, Never>,
        timeTarget: SignalProducer<TimeTarget?, Never>,
        periodPreference: SignalProducer<PeriodPreference, Never>,
        userUpdates: BindingTarget<TimeTarget>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: -

    lazy var calendar = lastBinding.producer.skipNil().map { $0.calendar }.flatten(.latest)
    lazy var timeTarget = lastBinding.producer.skipNil().map { $0.timeTarget }.flatten(.latest)
    // Emits non nil timeTarget values coming through the interface
    lazy var nonNilTimeTarget = timeTarget.producer.skipNil()

    // MARK: - Output

    private var userUpdates = MutableProperty<TimeTarget?>(nil)

    // MARK: - Outlets

    @IBOutlet weak var hoursTargetLabel: NSTextField!
    @IBOutlet weak var hoursTargetField: NSTextField!
    @IBOutlet weak var hoursTargetStepper: NSStepper!
    @IBOutlet weak var periodDescriptionLabel: NSTextField!
    @IBOutlet weak var hoursTargetFormatter: NumberFormatter!
    @IBOutlet weak var activeWeekdaysLabel: NSTextField!
    @IBOutlet weak var activeWeekdaysControl: NSSegmentedControl!
    @IBOutlet weak var deleteTimeTargetButton: NSButton!

    // MARK: - Wiring

    /// Populates the active weekdays control with short weekday symbols
    /// taken from the received Calendar values.
    private lazy var weekdaySegments = activeWeekdaysControl.reactive
        .makeBindingTarget(on: UIScheduler()) { (control: NSSegmentedControl, calendar: Calendar) in
            let displayDaySymbols = calendar.veryShortStandaloneWeekdaySymbols
            let toolTipDaySymbols = calendar.standaloneWeekdaySymbols
            let dayCount = displayDaySymbols.count
            assert(dayCount == Weekday.allCases.count)
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

        deleteTimeTargetButton.image!.isTemplate = true

        userUpdates.signal.skipNil().bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.userUpdates })

        // Populate controls that depend on calendar values
        weekdaySegments <~ calendar

        bindInputTimeTargetsToControls()
        bindControlsToOutputTimeTargets()
        enableControlsOnlyIfTimeTargetExists()
        setupTimeTargetDeletionAction()
    }

    private func bindInputTimeTargetsToControls() {
        // Bind timeTarget values to the values displayed in the controls
        hoursTargetField.reactive.text <~ nonNilTimeTarget.map { $0.hoursTarget }
            .map(NSNumber.init)
            .map(hoursTargetFormatter.string(from:))
            .map { $0 ?? "" }

        hoursTargetStepper.reactive.integerValue <~ nonNilTimeTarget.map { $0.hoursTarget }

        activeWeekdaysControl.reactive
            .makeBindingTarget(on: UIScheduler()) { $0.setSelected($1.0, forSegment: $1.1) }
            <~ Property(value: Weekday.allCases).producer
                .sample(on: nonNilTimeTarget.map { _ in () })
                .map(SignalProducer<Weekday, Never>.init)
                .flatten(.latest)
                .withLatest(from: nonNilTimeTarget.map { $0.workWeekdays })
                .map { ($1.isSelected($0), $0.indexInGregorianCalendarSymbolsArray) }

        // Bind period preference to period description
        periodDescriptionLabel.reactive.stringValue <~ lastBinding.producer.skipNil()
            .map { $0.periodPreference }.flatten(.latest)
            .map {
                switch $0 {
                case .monthly: return NSLocalizedString(
                    "time-target-controller.target-hours-period.month", // swiftlint:disable:next line_length
                    comment: "month period description as it appears next to the target hours field in the time target VC")
                case .weekly: return NSLocalizedString(
                    "time-target-controller.target-hours-period.week", // swiftlint:disable:next line_length
                    comment: "week period description as it appears next to the target hours field in the time target VC")
                }
        }

        // Bind hours stepper buttons and hours target field
        hoursTargetField.reactive.integerValue <~ hoursTargetStepper.reactive.integerValues
        hoursTargetStepper.reactive.integerValue <~ hoursTargetField.reactive.integerValues
    }

    private func bindControlsToOutputTimeTargets() {
        let textFieldValues = hoursTargetField.reactive.stringValues
            .filterMap { [weak formatter = hoursTargetFormatter] (text) -> HoursTargetType? in
                formatter?.number(from: text)?.intValue
        }
        let stepperValues = hoursTargetStepper.reactive.integerValues

        let timeTargetFromEditedHours = Signal.merge(textFieldValues, stepperValues)
            .producer
            .withLatest(from: nonNilTimeTarget)
            .map { TimeTarget(for: $1.projectId, hoursTarget: $0, workWeekdays: $1.workWeekdays) }

        let timeTargetFromEditedActiveWeekdays = activeWeekdaysControl.reactive.selectedSegmentIndexes
            .map { [weak activeWeekdaysControl] (_) -> WeekdaySelection? in
                guard let control = activeWeekdaysControl else {
                    return nil
                }
                var newSelection = WeekdaySelection.empty

                for day in Weekday.allCases {
                    if control.isSelected(forSegment: day.indexInGregorianCalendarSymbolsArray) {
                        newSelection.select(day)
                    }
                }

                return newSelection
            }.skipNil()
            .producer
            .withLatest(from: nonNilTimeTarget)
            .map { TimeTarget(for: $1.projectId, hoursTarget: $1.hoursTarget, workWeekdays: $0) }

        let editedTimeTarget = SignalProducer.merge(timeTargetFromEditedHours,
                                                    timeTargetFromEditedActiveWeekdays)

        userUpdates <~ editedTimeTarget.map { Optional($0) }
    }

    private func enableControlsOnlyIfTimeTargetExists() {
        let timeTargetExists = timeTarget.producer.map { $0 != nil }.skipRepeats()
        for control in [hoursTargetLabel, hoursTargetField, activeWeekdaysLabel,
                        activeWeekdaysControl, deleteTimeTargetButton] as [NSControl] {
                            control.reactive.isEnabled <~ timeTargetExists
        }
    }

    private func setupTimeTargetDeletionAction() {
        let deleteButtonPressed = Action<Void, Void, Never> { SignalProducer(value: ()) }
        deleteTimeTargetButton.reactive.pressed = CocoaAction(deleteButtonPressed)
        let deleteTimeTarget = reactive.makeBindingTarget { (timeTargetVC, _: Void) in
            timeTargetVC.tryToPerform(#selector(TimeTargetCreatingDeleting.deleteTimeTarget(_:)), with: timeTargetVC)
        }
        deleteTimeTarget <~ deleteButtonPressed.values
    }

    // MARK: - Onboarding

    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, Never>] {
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

        let activeWeekdaysEdited = activeWeekdaysControl.map { $0.reactive.selectedSegmentIndexes.map { _ in () } }
            .flatten(.concat)

        let workWeekdaysView = activeWeekdaysControl
            .map { $0 as NSView }
            .concat(SignalProducer.never)
            .take(until: activeWeekdaysEdited)

        return [.setTargetHours: targetHoursView,
                .setWorkWeekdays: workWeekdaysView]
    }
}

// MARK: -

class NoTimeTargetViewController: NSViewController, OnboardingTargetViewsProvider {
    @IBOutlet weak var createTimeTargetButton: NSButton!

    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, Never>] {
        let createTimeTargetButtonPressed = Action<Void, Void, Never> {
            SignalProducer(value: ())
        }

        let viewDidAppearProducer = reactive.trigger(for: #selector(viewDidAppear)).producer.take(first: 1)

        let timeTargetCreationViewProducer = viewDidAppearProducer
            .on(value: { [unowned self] in
                self.createTimeTargetButton.reactive.pressed = CocoaAction(createTimeTargetButtonPressed)
            })
        .map (value: self.createTimeTargetButton as NSView)

        let timeTargetCreationView = timeTargetCreationViewProducer.concat(SignalProducer.never)
            .take(until: createTimeTargetButtonPressed.values)

        return [.createTimeTarget: timeTargetCreationView]
    }
}
