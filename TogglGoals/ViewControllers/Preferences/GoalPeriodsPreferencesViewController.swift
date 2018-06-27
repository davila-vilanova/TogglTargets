//
//  GoalPeriodsPreferencesViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 03.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

internal let DefaultPeriodPreference = PeriodPreference.monthly

class GoalPeriodsPreferencesViewController: NSViewController, BindingTargetProvider {

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
    private let existingPreference = MutableProperty<PeriodPreference>(DefaultPeriodPreference)

    private lazy var updatedPreference: Signal<PeriodPreference, NoError> =
        Signal.merge(generateMonthlyPeriodPreference.values, generateWeeklyPeriodPreference.values)


    // MARK: - Outlets and action

    @IBOutlet weak var preferMonthlyGoalPeriodsButton: NSButton!
    @IBOutlet weak var preferWeeklyGoalPeriodsButton: NSButton!
    @IBOutlet weak var weeklyGoalStartDayLabel: NSTextField!
    @IBOutlet weak var weeklyGoalStartDayPopUp: NSPopUpButton!
    @IBOutlet weak var currentPeriodStart: NSTextField!
    @IBOutlet weak var currentPeriodEnd: NSTextField!

    // MARK: - State

    private lazy var isWeeklyPreferenceSelectedProperty =
        Property<Bool>(initial: DefaultPeriodPreference.isWeekly,                 // default value
            then: SignalProducer.merge(existingPreference.producer.map(isWeekly), // value from upstream
                       weeklyButtonPress.values.producer.map { _ in true },       // value from user input
                       generateMonthlyPeriodPreference.values.producer.map { _ in false }))

    private lazy var selectedWeekdayProperty: MutableProperty<Weekday> = {
        // default value
        let p = MutableProperty(
            DefaultPeriodPreference.selectedWeekday ?? (Weekday.fromIndexInGregorianCalendarSymbolsArray(0)!))

        // value from upstream
        p <~ existingPreference.map(selectedWeekday).producer.skipNil()

        // value from user input
        p <~ weeklyGoalStartDayPopUp.reactive.selectedIndexes
            .map(Weekday.fromIndexInGregorianCalendarSymbolsArray)
            .skipNil()
        return p
    }()


    // MARK: - Actions

    private let weeklyButtonPress = Action() { SignalProducer(value: ()) }
    private let generateMonthlyPeriodPreference = Action() { SignalProducer(value: PeriodPreference.monthly) }
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
        preferMonthlyGoalPeriodsButton.reactive.state <~ preferWeeklyGoalPeriodsButton
            .reactive.states.map { $0 == .off ? .on : .off }
        
        preferWeeklyGoalPeriodsButton.reactive.state <~ preferMonthlyGoalPeriodsButton
            .reactive.states.map { $0 == .off ? .on : .off }
    }

    private func populateWeekdaysPopUpButton() {
        let populateDaysTarget =
            weeklyGoalStartDayPopUp.reactive.makeBindingTarget { (button, weekdaySymbols: [String]) in
                button.removeAllItems()
                for dayName in weekdaySymbols {
                    button.addItem(withTitle: dayName)
                }
        }

        populateDaysTarget <~ calendar.producer.skipNil().map { $0.weekdaySymbols }
    }

    private func reflectExistingPreference() {
        preferMonthlyGoalPeriodsButton.reactive.state <~ existingPreference
            .map(isMonthly)
            .map(boolToControlStateValue)

        preferWeeklyGoalPeriodsButton.reactive.state <~ existingPreference
            .map(isWeekly)
            .map(boolToControlStateValue)

        weeklyGoalStartDayPopUp.reactive.selectedIndex <~ existingPreference
            .map(selectedWeekday)
            .producer.skipNil()
            .map { $0.rawValue }
    }

    private func assignActions() {
        preferMonthlyGoalPeriodsButton.reactive.pressed = CocoaAction(generateMonthlyPeriodPreference)
        preferWeeklyGoalPeriodsButton.reactive.pressed = CocoaAction(weeklyButtonPress)
        weeklyGoalStartDayPopUp.reactive.pressed = CocoaAction(generateWeeklyPeriodPreference, weekdayFromSelection)

        // Take the value of selectedWeekdayProperty at the time weeklyButtonPress fires
        // and forward it to the generateWeeklyPeriodPreference Action
        generateWeeklyPeriodPreference <~ selectedWeekdayProperty.producer.sample(on: weeklyButtonPress.values)
    }

    private func reflectCurrentPeriod() {
        let userModifiedPreference = updatedPreference

        let currentPeriod =
            SignalProducer.combineLatest(SignalProducer.merge(existingPreference.producer, userModifiedPreference.producer),
                                                              calendar.producer.skipNil(),
                                                              currentDate.producer.skipNil())
            .map { (preference, calendar, currentDate) in
                preference.currentPeriod(in: calendar, for: currentDate)
        }

        let formatter: SignalProducer<DateFormatter, NoError> = {
            let f = DateFormatter()
            f.dateStyle = .full
            f.timeStyle = .none
            return SignalProducer(value: f)
        }()

        func formattedDayComponents(_ dayComponents: SignalProducer<DayComponents, NoError>)
            -> SignalProducer<String, NoError> {
                return dayComponents.combineLatest(with: calendar.producer.skipNil())
                    .map { (dayComponents, calendar) in
                        // try! because the components are trusted, generated by PeriodPreference
                        try! calendar.date(from: dayComponents)
                    }.combineLatest(with: formatter)
                    .map { (date, formatter) in
                        formatter.string(from: date)
                }
        }

        currentPeriodStart.reactive.stringValue <~ formattedDayComponents(currentPeriod.map { $0.start })
        currentPeriodEnd.reactive.stringValue <~ formattedDayComponents(currentPeriod.map { $0.end })
    }
}


// MARK: -

fileprivate func weekdayToWeeklyPeriodPreferenceProducer(_ weekday: Weekday)
    -> SignalProducer<PeriodPreference, NoError> {
        return SignalProducer(value: PeriodPreference.weekly(startDay: weekday))
}

fileprivate func boolToControlStateValue(_ bool: Bool) -> NSControl.StateValue {
    switch bool {
    case true: return .on
    case false: return .off
    }
}

fileprivate func weekdayFromSelection(in popup: NSPopUpButton) -> Weekday {
    return Weekday.fromIndexInGregorianCalendarSymbolsArray(popup.indexOfSelectedItem)!
}
