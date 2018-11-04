//
//  APITokenViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 01.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
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
        credentialUpstream <~ apiTokenField.reactive.continuousStringValues.map(TogglAPITokenCredential.init)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        reactive.makeBindingTarget { $1.makeFirstResponder($0.apiTokenField) } <~
            reactive.producer(forKeyPath: "view.window").skipNil().filterMap { $0 as? NSWindow }
                .delay(0, on: QueueScheduler())
                .take(first: 1)
    }
}
