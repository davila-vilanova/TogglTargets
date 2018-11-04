//
//  EmailPasswordViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 01.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

class EmailPasswordViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        credentialUpstream: BindingTarget<TogglAPICredential?>,
        attemptLogin: BindingTarget<Void>,
        switchToDirectTokenEntry: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Outlets and Actions

    @IBOutlet weak var emailField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!

    @IBAction func switchToDirectTokenEntry(_ sender: AnyObject) {
        requestSwitchToTokenController <~ SignalProducer(value: ())
    }

    @IBAction func enterPressed(_ sender: Any) {
        attemptLogin <~ SignalProducer(value: ())
    }

    // MARK: -

    private let requestSwitchToTokenController = MutableProperty<Void>(())
    private let attemptLogin = MutableProperty<Void>(())

    override func viewDidLoad() {
        super.viewDidLoad()

        let credentialUpstream = Signal.combineLatest(emailField.reactive.continuousStringValues,
                                                      passwordField.reactive.continuousStringValues)
            .map(TogglAPIEmailCredential.init)
            // (The following mapping should be much simpler but for some reason I cannot condense it without upsetting the compiler)
            // Generalize the optional TogglAPIEmailCredential values to optional TogglAPICredential values
            .map { credentialOrNil -> TogglAPICredential? in
                if let emailCredential = credentialOrNil {
                    return emailCredential as TogglAPICredential
                } else {
                    return nil
                }
        }

        let validBindings = lastBinding.producer.skipNil()
        credentialUpstream.bindOnlyToLatest(validBindings.map { $0.credentialUpstream })
        requestSwitchToTokenController.signal.bindOnlyToLatest(validBindings.map { $0.switchToDirectTokenEntry })
        attemptLogin.signal.bindOnlyToLatest(validBindings.map { $0.attemptLogin })
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        reactive.makeBindingTarget { $1.makeFirstResponder($0.emailField) } <~
            reactive.producer(forKeyPath: "view.window").skipNil().filterMap { $0 as? NSWindow }
                .delay(0, on: QueueScheduler())
                .take(first: 1)
    }
}
