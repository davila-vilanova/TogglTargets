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

class PreferencesViewController: NSTabViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        existingGoalPeriodPreference: SignalProducer<PeriodPreference, NoError>,
        userDefaults: SignalProducer<UserDefaults, NoError>,
        calendar: SignalProducer<Calendar, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        resolvedCredential: BindingTarget<TogglAPITokenCredential>,
        updatedGoalPeriodPreference: BindingTarget<PeriodPreference>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


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

        loginViewController <~ lastBinding.producer.skipNil()
            .map { ($0.userDefaults, $0.resolvedCredential) }

        goalPeriodsController <~ lastBinding.producer.skipNil()
            .map { ($0.calendar, $0.currentDate, $0.existingGoalPeriodPreference, $0.updatedGoalPeriodPreference) }
    }
}
