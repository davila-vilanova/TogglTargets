//
//  EmailPasswordViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 01.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

class EmailPasswordViewController: NSViewController, KeyViewsProviding, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        credentialUpstream: BindingTarget<TogglAPICredential?>,
        switchToTokenController: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Outlets and Action

    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!

    @IBAction func switchToDirectTokenEntry(_ sender: AnyObject) {
        requestSwitchToTokenController <~ SignalProducer(value: ())
    }

    // MARK: - KeyViewsProviding

    var firstKeyView: NSView { return usernameField }
    var lastKeyView: NSView { return passwordField }


    // MARK: -

    private let requestSwitchToTokenController = MutableProperty<Void>(())

    override func viewDidLoad() {
        super.viewDidLoad()

        let credentialUpstream = Signal.combineLatest(usernameField.reactive.continuousStringValues,
                                                      passwordField.reactive.continuousStringValues)
            .map(TogglAPIEmailCredential.init)
            .map { $0 as TogglAPICredential? }

        let validBindings = lastBinding.producer.skipNil()
        credentialUpstream.bindOnlyToLatest(validBindings.map { $0.credentialUpstream })
        requestSwitchToTokenController.signal.bindOnlyToLatest(validBindings.map { $0.switchToTokenController })
    }
}
