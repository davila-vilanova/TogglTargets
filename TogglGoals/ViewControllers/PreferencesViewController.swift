//
//  PreferencesViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

class PreferencesViewController: NSTabViewController {

    // MARK: - Inputs

    internal func connectInputs(existingGoalPeriodPreference: SignalProducer<PeriodPreference, NoError>,
                                userDefaults: SignalProducer<UserDefaults, NoError>,
                                calendar: SignalProducer<Calendar, NoError>,
                                currentDate: SignalProducer<Date, NoError>) {
        enforceOnce(for: "PreferencesViewController.connectInputs()") {
            self.areChildrenControllersAvailable.firstTrue.startWithValues {
                self.loginViewController.connectInputs(userDefaults: userDefaults)
                self.goalPeriodsController.connectInputs(calendar: calendar,
                                                         currentDate: currentDate,
                                                         periodPreference: existingGoalPeriodPreference)
            }
        }
    }

    // MARK: - Outputs

    internal var resolvedCredential: Signal<TogglAPITokenCredential?, NoError> { return _resolvedCredential.signal }
    internal var updatedGoalPeriodPreference: Signal<PeriodPreference, NoError> { return _updatedGoalPeriodPreference.signal.skipNil() }

    // MARK: - Backing of reactive interface

    private let _resolvedCredential = MutableProperty<TogglAPITokenCredential?>(nil)
    private let _updatedGoalPeriodPreference = MutableProperty<PeriodPreference?>(nil)


    // MARK: - Contained view controllers

    /// Represents the tab items this controller contains
    private enum SplitItemIndex: Int {
        case accountLogin = 0
        case goalPeriods
    }

    private var loginViewController: LoginViewController {
        return tabViewItem(.accountLogin).viewController as! LoginViewController
    }

    private var goalPeriodsController: GoalPeriodsPreferencesViewController {
        return tabViewItem(.goalPeriods).viewController as! GoalPeriodsPreferencesViewController
    }
    
    private func tabViewItem(_ index: SplitItemIndex) -> NSTabViewItem {
        return tabViewItems[index.rawValue]
    }

    private let areChildrenControllersAvailable = MutableProperty(false)


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        areChildrenControllersAvailable.value = true

        _resolvedCredential <~ loginViewController.resolvedCredential
        _updatedGoalPeriodPreference <~ goalPeriodsController.updatedPreference
    }
}
