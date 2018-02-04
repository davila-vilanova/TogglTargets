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

    // MARK: - Exposed reactive interface

    internal var resolvedCredential: Signal<TogglAPITokenCredential?, NoError> { return _resolvedCredential.signal }
    internal var existingGoalPeriodPreference: BindingTarget<PeriodPreference> { return _existingGoalPeriodPreference.deoptionalizedBindingTarget }
    internal var updatedGoalPeriodPreference: Signal<PeriodPreference, NoError> { return _updatedGoalPeriodPreference.signal.skipNil() }
    internal var userDefaults: BindingTarget<UserDefaults> { return _userDefaults.deoptionalizedBindingTarget }
    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    internal var currentDate: BindingTarget<Date> { return _currentDate.deoptionalizedBindingTarget }

    // MARK: - Backing of reactive interface

    private let _resolvedCredential = MutableProperty<TogglAPITokenCredential?>(nil)
    private let _existingGoalPeriodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _updatedGoalPeriodPreference = MutableProperty<PeriodPreference?>(nil)
    private let _userDefaults = MutableProperty<UserDefaults?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _currentDate = MutableProperty<Date?>(nil)


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

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        loginViewController.userDefaults <~ _userDefaults.producer.skipNil()
        _resolvedCredential <~ loginViewController.resolvedCredential
        
        _updatedGoalPeriodPreference <~ goalPeriodsController.updatedPreference
        goalPeriodsController.connectInputs(calendar: _calendar.producer.skipNil(),
                                            currentDate: _currentDate.producer.skipNil(),
                                            periodPreference: _existingGoalPeriodPreference.producer.skipNil())
    }
}
