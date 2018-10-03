//
//  PreferencesViewControllerWrapper.swift
//  TogglGoals
//
//  Created by David Dávila on 13.08.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class PreferencesViewControllerWrapper: NSViewController, BindingTargetProvider, CloseLoginViewProviding {

    internal typealias Interface = PreferencesViewController.Interface

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let prefsController = segue.destinationController as? PreferencesViewController {
            prefsController <~ lastBinding
        }
    }

    @IBOutlet weak var closePreferencesButton: NSButton!

    @IBAction func closePreferences(_ sender: Any) {
        if let window = view.window,
            let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            _ = `try`(toPerform: #selector(NSWindow.close), with: sender)
        }
    }


    // MARK: - Onboarding

    var closeLoginView: SignalProducer<NSView, NoError> {
        let closeButtonPressedAction = Action<Void, Void, NoError> { SignalProducer(value: ()) }
        let closePreferencesButtonProducer = viewDidLoadProducer
            .on(value: { [unowned self] in
                self.closePreferencesButton.reactive.pressed = CocoaAction(closeButtonPressedAction)
            })
            .map { [unowned self] in self.closePreferencesButton as NSView }

        return closePreferencesButtonProducer.concat(SignalProducer.never).take(until: closeButtonPressedAction.values)
    }
}
