//
//  LoginMethodViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 11.08.18.
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

class LoginMethodViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (credentialUpstream: BindingTarget<TogglAPICredential?>,
        attemptLogin: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Contained view controllers

    private lazy var tokenViewController: APITokenViewController = {
        let tokenController = self.storyboard!.instantiateController(withIdentifier: "APITokenViewController")
            as! APITokenViewController // swiftlint:disable:this force_cast

        tokenController <~ SignalProducer
            .combineLatest(lastBinding.producer.skipNil().map { ($0.credentialUpstream, $0.attemptLogin) },
                           SignalProducer(value: switchToEmailPasswordController.bindingTarget))
            .map { (credentialUpstream: $0.0.0, attemptLogin: $0.0.1, switchToEmailPasswordEntry: $0.1) }

        addChild(tokenController)

        return tokenController
    }()

    private lazy var emailPasswordViewController: EmailPasswordViewController = {
        let emailPasswordController = self.storyboard!
            .instantiateController(withIdentifier: "EmailPasswordViewController") as! EmailPasswordViewController
        // swiftlint:disable:previous force_cast

        emailPasswordController <~ SignalProducer
            .combineLatest(lastBinding.producer.skipNil().map { ($0.credentialUpstream, $0.attemptLogin) },
                           SignalProducer(value: switchToTokenController.bindingTarget))
            .map { (credentialUpstream: $0.0.0, attemptLogin: $0.0.1, switchToDirectTokenEntry: $0.1) }

        addChild(emailPasswordController)

        return emailPasswordController
    }()

    private let switchToEmailPasswordController = MutableProperty(())
    private let switchToTokenController = MutableProperty(())

    private enum SelectedEntryMethod {
        case token
        case emailPassword
    }
    private let selectedEntryMethod = MutableProperty(SelectedEntryMethod.token)

    @IBOutlet weak var containerView: NSView!

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        selectedEntryMethod <~ Signal.merge(switchToEmailPasswordController.signal.map { .emailPassword },
                                            switchToTokenController.signal.map { .token })

        containerView.uniqueSubview <~ selectedEntryMethod
            .producer
            .observe(on: UIScheduler())
            .map { [unowned self] entryMethod in
                switch entryMethod {
                case .emailPassword: return self.emailPasswordViewController.view
                case .token: return self.tokenViewController.view
                }
        }
    }
}
