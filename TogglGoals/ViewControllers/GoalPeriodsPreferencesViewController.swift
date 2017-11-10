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

class GoalPeriodsPreferencesViewController: NSViewController {

    // MARK: - Reactive interface

    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    internal var existingPreference: BindingTarget<PeriodPreference> { return _existingPreference.bindingTarget }
    internal var updatedPreference: Signal<PeriodPreference, NoError> {
        return Signal.merge(generateMonthlyPeriodPreference.values,
                            generateWeeklyPeriodPreference.values)
    }


    // MARK: - Backing properties

    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _existingPreference = MutableProperty<PeriodPreference>(DefaultPeriodPreference)


    // MARK: - IBOutlets

    @IBOutlet weak var preferMonthlyGoalPeriodsButton: NSButton!
    @IBOutlet weak var preferWeeklyGoalPeriodsButton: NSButton!
    @IBOutlet weak var weeklyGoalStartDayLabel: NSTextField!
    @IBOutlet weak var weeklyGoalStartDayPopUp: NSPopUpButton!


    // MARK: - State

    private lazy var isWeeklyPreferenceSelectedProperty: MutableProperty<Bool> = {
        let p = MutableProperty(isWeeklyPreference(DefaultPeriodPreference)) // default value
        p <~ _existingPreference.map(isWeeklyPreference) // value from upstream
        p <~ weeklyButtonPress.values.map { _ in true }
        p <~ generateMonthlyPeriodPreference.values.map { _ in false }
        return p
    }()

    private lazy var selectedWeekdayProperty: MutableProperty<Weekday> = {
        let p = MutableProperty(
            selectedWeekday(in: DefaultPeriodPreference) ?? (Weekday.fromIndexInGregorianCalendarSymbolsArray(0)!)) // default value
        p <~ weeklyGoalStartDayPopUp.reactive.selectedIndexes.map(Weekday.fromIndexInGregorianCalendarSymbolsArray).skipNil()
        return p
    }()


    // MARK: - Actions

    private let weeklyButtonPress = Action() { SignalProducer(value: ()) }
    private let generateMonthlyPeriodPreference = Action() { SignalProducer(value: PeriodPreference.monthly) }
    private lazy var generateWeeklyPeriodPreference =
        Action<Weekday, PeriodPreference, NoError> (enabledIf: isWeeklyPreferenceSelectedProperty,
                                                    execute: weekdayToWeeklyPeriodPreferenceProducer)


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        makeRadioButtonSelectionMutuallyExclusive()
        populateWeekdaysPopUpButton()
        reflectExistingPreference()
        assignActions()
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

        populateDaysTarget <~ _calendar.producer.skipNil().map { $0.weekdaySymbols }
    }

    private func reflectExistingPreference() {
        preferMonthlyGoalPeriodsButton.reactive.state <~ _existingPreference
            .map(isMonthlyPreference)
            .map(boolToControlStateValue)

        preferWeeklyGoalPeriodsButton.reactive.state <~ _existingPreference
            .map(isWeeklyPreference)
            .map(boolToControlStateValue)

        weeklyGoalStartDayPopUp.reactive.selectedIndex <~ _existingPreference
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

// TODO: verbose and messy. What did I not get about enumerations?
fileprivate func isMonthlyPreference(_ pref: PeriodPreference) -> Bool {
    switch pref {
    case .monthly: return true
    default: return false
    }
}

fileprivate func isWeeklyPreference(_ pref: PeriodPreference) -> Bool {
    switch pref {
    case .weekly: return true
    default: return false
    }
}

fileprivate func selectedWeekday(in preference: PeriodPreference) -> Weekday? {
    switch preference {
    case .weekly(let weekday): return weekday
    default: return nil
    }
}
