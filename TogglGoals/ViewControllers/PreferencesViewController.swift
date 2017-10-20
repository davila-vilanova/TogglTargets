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

    internal var credentialDownstream: BindingTarget<TogglAPICredential?> { return _credentialDownstream.bindingTarget }
    internal var credentialUpstream: Signal<TogglAPICredential?, NoError> { return _credentialUpstream.signal }


    // MARK: - Backing of reactive interface

    internal var _credentialDownstream = MutableProperty<TogglAPICredential?>(nil)
    internal var _credentialUpstream = MutableProperty<TogglAPICredential?>(nil)


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
        
        loginViewController.credential <~ _credentialDownstream
        _credentialUpstream <~ loginViewController.userUpdates
    }
}
