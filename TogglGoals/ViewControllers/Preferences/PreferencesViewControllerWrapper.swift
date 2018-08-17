//
//  PreferencesViewControllerWrapper.swift
//  TogglGoals
//
//  Created by David Dávila on 13.08.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift

class PreferencesViewControllerWrapper: NSViewController, BindingTargetProvider {

    internal typealias Interface = PreferencesViewController.Interface

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let prefsController = segue.destinationController as? PreferencesViewController {
            prefsController <~ lastBinding
        }
    }
}
