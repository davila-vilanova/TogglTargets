//
//  APITokenViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 01.05.18.
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
import ReactiveSwift
import ReactiveCocoa

class APITokenViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        credentialUpstream: BindingTarget<TogglAPICredential?>,
        attemptLogin: BindingTarget<Void>,
        switchToEmailPasswordEntry: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Outlet and Actions

    @IBOutlet weak var apiTokenField: NSTextField!

    @IBAction func switchToEmailPasswordEntry(_ sender: AnyObject) {
        requestSwitchToEmailPasswordEntry <~ SignalProducer(value: ())
    }

    @IBAction func enterPressed(_ sender: Any) {
        attemptLogin <~ SignalProducer(value: ())
    }

    // MARK: - Wiring

    private let requestSwitchToEmailPasswordEntry = MutableProperty<Void>(())
    private let attemptLogin = MutableProperty<Void>(())

    override func viewDidLoad() {
        super.viewDidLoad()

        // Connect to interface
        let credentialUpstream = MutableProperty<TogglAPICredential?>(nil)
        let validBindings = lastBinding.producer.skipNil()
        credentialUpstream.bindOnlyToLatest(validBindings.map { $0.credentialUpstream })
        requestSwitchToEmailPasswordEntry.signal.bindOnlyToLatest(validBindings.map { $0.switchToEmailPasswordEntry })
        attemptLogin.signal.bindOnlyToLatest(validBindings.map { $0.attemptLogin })

        // Send upstream a credential based on the value displayed in the token field
        let apiTokenValues: Signal<(any TogglAPICredential)?, Never> = apiTokenField.reactive.continuousStringValues.map(TogglAPITokenCredential.init)
        credentialUpstream <~ apiTokenValues
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        reactive.makeBindingTarget { $1.makeFirstResponder($0.apiTokenField) } <~
        reactive.producer(forKeyPath: "view.window").skipNil().compactMap { $0 as? NSWindow }
                .delay(0, on: QueueScheduler())
                .take(first: 1)
    }
}
