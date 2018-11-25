//
//  PreferencesViewControllerWrapper.swift
//  TogglTargets
//
//  Created by David Dávila on 13.08.18.
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

class PreferencesViewControllerWrapper: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    internal typealias Interface = PreferencesViewController.Interface

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let prefsController = segue.destinationController as? PreferencesViewController {
            prefsController <~ lastBinding
        }
    }

    @IBOutlet weak var closePreferencesButton: NSButton!

    @IBAction func closePreferences(_ sender: Any?) {
        if let window = view.window,
            let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            _ = tryToPerform(#selector(NSWindow.close), with: sender)
        }
    }

    // NSResponder: -

    override func cancelOperation(_ sender: Any?) {
        closePreferences(sender)
    }

    // MARK: - Onboarding

    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, NoError>] {
        let closeButtonPressedAction = Action<Void, Void, NoError> { SignalProducer(value: ()) }
        let closePreferencesButtonProducer = viewDidLoadProducer
            .on(value: { [unowned self] in
                self.closePreferencesButton.reactive.pressed = CocoaAction(closeButtonPressedAction)
            })
            .map { [unowned self] in self.closePreferencesButton as NSView }
        let closeLoginView = closePreferencesButtonProducer.concat(SignalProducer.never)
            .take(until: closeButtonPressedAction.values)
        return [.closeLogin: closeLoginView]
    }
}
