//
//  APITokenViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 01.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

class APITokenViewController: NSViewController, KeyViewsProviding, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        credentialUpstream: BindingTarget<TogglAPICredential?>,
        switchToEmailPasswordController: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Outlet and Action

    @IBOutlet weak var apiTokenField: NSTextField!

    @IBAction func switchToEmailPasswordEntry(_ sender: AnyObject) {
        requestSwitchToEmailPasswordController <~ SignalProducer(value: ())
    }


    // MARK: - KeyViewsProviding

    var firstKeyView: NSView { return apiTokenField }
    var lastKeyView: NSView { return apiTokenField }


    // MARK: - Wiring

    private let (lifetime, token) = Lifetime.make()
    private let requestSwitchToEmailPasswordController = MutableProperty<Void>(())

    override func viewDidLoad() {
        super.viewDidLoad()

        // Connect to interface
        let credentialUpstream = MutableProperty<TogglAPICredential?>(nil)
        let validBindings = lastBinding.producer.skipNil()
        credentialUpstream.bindOnlyToLatest(validBindings.map { $0.credentialUpstream })
        requestSwitchToEmailPasswordController.signal.bindOnlyToLatest(validBindings.map { $0.switchToEmailPasswordController })


        // Send upstream a credential based on the value displayed in the token field
        credentialUpstream <~ apiTokenField.reactive.continuousStringValues.map(TogglAPITokenCredential.init)
    }
}
