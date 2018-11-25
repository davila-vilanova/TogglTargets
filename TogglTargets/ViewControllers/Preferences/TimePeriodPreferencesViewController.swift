//
//  TimePeriodPreferencesViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 03.11.17.
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
import Result
import ReactiveSwift
import ReactiveCocoa

internal let defaultPeriodPreference = PeriodPreference.monthly

class TimePeriodPreferencesViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        calendar: SignalProducer<Calendar, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        updatedPreference: BindingTarget<PeriodPreference>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Backing properties and signals

    private let calendar = MutableProperty<Calendar?>(nil)
    private let currentDate = MutableProperty<Date?>(nil)
    private let existingPreference = MutableProperty<PeriodPreference>(defaultPeriodPreference)

    private lazy var updatedPreference: Signal<PeriodPreference, NoError> =
        Signal.merge(generateMonthlyPeriodPreference.values, generateWeeklyPeriodPreference.values)

    // MARK: - Outlets and action

    @IBOutlet weak var preferMonthlyPeriodButton: NSButton!
    @IBOutlet weak var preferWeeklyPeriodButton: NSButton!
    @IBOutlet weak var weeklyStartDayLabel: NSTextField!
    @IBOutlet weak var weeklyStartDayPopUp: NSPopUpButton!
    @IBOutlet weak var currentPeriodDescription: NSTextField!

    // MARK: - State

    private lazy var isWeeklyPreferenceSelectedProperty =
        Property<Bool>(initial: defaultPeriodPreference.isWeekly,                 // default value
            then: SignalProducer.merge(existingPreference.producer.map(isWeekly), // value from upstream
                       weeklyButtonPress.values.producer.map { _ in true },       // value from user input
                       generateMonthlyPeriodPreference.values.producer.map { _ in false }))

    private lazy var selectedWeekdayProperty: MutableProperty<Weekday> = {
        // default value
        let selected = MutableProperty(
            defaultPeriodPreference.selectedWeekday ?? (Weekday.fromIndexInGregorianCalendarSymbolsArray(0)!))

        // value from upstream
        selected <~ existingPreference.map(selectedWeekday).producer.skipNil()

        // value from user input
        selected <~ weeklyStartDayPopUp.reactive.selectedIndexes
            .map(Weekday.fromIndexInGregorianCalendarSymbolsArray)
            .skipNil()
        return selected
    }()

    // MARK: - Actions

    private let weeklyButtonPress = Action { SignalProducer(value: ()) }
    private let generateMonthlyPeriodPreference = Action { SignalProducer(value: PeriodPreference.monthly) }
    private lazy var generateWeeklyPeriodPreference =
        Action<Weekday, PeriodPreference, NoError> (enabledIf: isWeeklyPreferenceSelectedProperty,
                                                    execute: weekdayToWeeklyPeriodPreferenceProducer)

    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        calendar <~ lastBinding.latestOutput { $0.calendar }
        currentDate <~ lastBinding.latestOutput { $0.currentDate }
        existingPreference <~ lastBinding.latestOutput { $0.periodPreference }

        let validBindings = lastBinding.producer.skipNil()
        updatedPreference.bindOnlyToLatest(validBindings.map { $0.updatedPreference })

        makeRadioButtonSelectionMutuallyExclusive()
        populateWeekdaysPopUpButton()
        reflectExistingPreference()
        assignActions()
        reflectCurrentPeriod()
    }

    private func makeRadioButtonSelectionMutuallyExclusive() {
        preferMonthlyPeriodButton.reactive.state <~ preferWeeklyPeriodButton
            .reactive.states.map { $0 == .off ? .on : .off }

        preferWeeklyPeriodButton.reactive.state <~ preferMonthlyPeriodButton
            .reactive.states.map { $0 == .off ? .on : .off }
    }

    private func populateWeekdaysPopUpButton() {
        let populateDaysTarget =
            weeklyStartDayPopUp.reactive.makeBindingTarget { (button, weekdaySymbols: [String]) in
                button.removeAllItems()
                for dayName in weekdaySymbols {
                    button.addItem(withTitle: dayName)
                }
        }

        populateDaysTarget <~ calendar.producer.skipNil().map { $0.weekdaySymbols }
    }

    private func reflectExistingPreference() {
        preferMonthlyPeriodButton.reactive.state <~ existingPreference
            .map(isMonthly)
            .map(boolToControlStateValue)

        preferWeeklyPeriodButton.reactive.state <~ existingPreference
            .map(isWeekly)
            .map(boolToControlStateValue)

        weeklyStartDayPopUp.reactive.selectedIndex <~ existingPreference
            .map(selectedWeekday)
            .producer.skipNil()
            .map { $0.rawValue }
    }

    private func assignActions() {
        preferMonthlyPeriodButton.reactive.pressed = CocoaAction(generateMonthlyPeriodPreference)
        preferWeeklyPeriodButton.reactive.pressed = CocoaAction(weeklyButtonPress)
        weeklyStartDayPopUp.reactive.pressed = CocoaAction(generateWeeklyPeriodPreference, weekdayFromSelection)

        // Take the value of selectedWeekdayProperty at the time weeklyButtonPress fires
        // and forward it to the generateWeeklyPeriodPreference Action
        generateWeeklyPeriodPreference <~ selectedWeekdayProperty.producer.sample(on: weeklyButtonPress.values)
    }

    private func reflectCurrentPeriod() {
        let userModifiedPreference = updatedPreference

        let currentPeriod =
            SignalProducer.combineLatest(SignalProducer.merge(existingPreference.producer,
                                                              userModifiedPreference.producer),
                                         calendar.producer.skipNil(),
                                         currentDate.producer.skipNil())
            .map { (preference, calendar, currentDate) in
                preference.period(in: calendar, for: currentDate)
        }

        let formatter: SignalProducer<DateFormatter, NoError> = {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .none
            return SignalProducer(value: formatter)
        }()

        func formattedDayComponents(_ dayComponents: SignalProducer<DayComponents, NoError>)
            -> SignalProducer<String, NoError> {
                return dayComponents.combineLatest(with: calendar.producer.skipNil())
                    .map { (dayComponents, calendar) in
                        // forced unwrap because the components are trusted, generated by PeriodPreference
                       calendar.date(from: dayComponents)!
                    }.combineLatest(with: formatter)
                    .map { (date, formatter) in
                        formatter.string(from: date)
                }
        }

        currentPeriodDescription.reactive.stringValue <~
            SignalProducer.combineLatest(formattedDayComponents(currentPeriod.map { $0.start }),
                                         formattedDayComponents(currentPeriod.map { $0.end }))
                .map { "\($0) to \($1)" }

    }

    override func viewDidAppear() {
        super.viewDidAppear()
        reactive.makeBindingTarget { $1.makeFirstResponder($0) } <~
            reactive.producer(forKeyPath: "view.window").skipNil().filterMap { $0 as? NSWindow }
                .delay(0, on: QueueScheduler())
                .take(first: 1)
    }
}

// MARK: -

private func weekdayToWeeklyPeriodPreferenceProducer(_ weekday: Weekday)
    -> SignalProducer<PeriodPreference, NoError> {
        return SignalProducer(value: PeriodPreference.weekly(startDay: weekday))
}

private func boolToControlStateValue(_ bool: Bool) -> NSControl.StateValue {
    switch bool {
    case true: return .on
    case false: return .off
    }
}

private func weekdayFromSelection(in popup: NSPopUpButton) -> Weekday {
    return Weekday.fromIndexInGregorianCalendarSymbolsArray(popup.indexOfSelectedItem)!
}
