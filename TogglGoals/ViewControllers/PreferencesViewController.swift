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
    internal var userDefaults: BindingTarget<UserDefaults> { return _userDefaults.deoptionalizedBindingTarget }


    // MARK: - Backing of reactive interface

    private let _resolvedCredential = MutableProperty<TogglAPITokenCredential?>(nil)
    private let _userDefaults = MutableProperty<UserDefaults?>(nil)


    // MARK: - Contained view controllers

    /// Represents the tab items this controller contains
    private enum SplitItemIndex: Int {
        case accountLogin = 0
        case goalPeriods
    }

    private var loginViewController: LoginViewController {
        return tabViewItem(.accountLogin).viewController as! LoginViewController
    }

    private func tabViewItem(_ index: SplitItemIndex) -> NSTabViewItem {
        return tabViewItems[index.rawValue]
    }

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        loginViewController.userDefaults <~ _userDefaults.producer.skipNil()
        _resolvedCredential <~ loginViewController.resolvedCredential
    }
}
