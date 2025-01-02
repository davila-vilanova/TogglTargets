//
//  AccountViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
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

class AccountViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        existingCredential: SignalProducer<TogglAPITokenCredential?, Never>,
        profile: SignalProducer<Profile, Never>,
        apiAccessError: SignalProducer<APIAccessError, Never>,
        resolvedCredential: BindingTarget<TogglAPITokenCredential?>,
        testURLSessionAction: RetrieveProfileNetworkAction)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Contained view controllers

    private lazy var loginViewController: LoginViewController = {
        let loginController = self.storyboard!.instantiateController(withIdentifier: "LoginViewController")
            as! LoginViewController // swiftlint:disable:this force_cast
        loginController <~ lastBinding.producer.skipNil().map { (credentialUpstream: $0.resolvedCredential,
                                                                 testURLSessionAction: $0.testURLSessionAction) }
        addChild(loginController)
        return loginController
    }()

    private lazy var loggedInViewController: LoggedInViewController = {
        let loggedInController = self.storyboard!.instantiateController(withIdentifier: "LoggedInViewController")
            as! LoggedInViewController // swiftlint:disable:this force_cast
        let validBindings = lastBinding.producer.skipNil()
        let logOutRequested = MutableProperty<Void>(())
        logOutRequested.signal.map { nil as TogglAPITokenCredential? }
            .bindOnlyToLatest(validBindings.map { $0.resolvedCredential })
        loggedInController <~ validBindings.map { (profile: $0.profile,
                                                   apiAccessError: $0.apiAccessError,
                                                   logOut: logOutRequested.bindingTarget) }
        return loggedInController
    }()

    @IBOutlet weak var containerView: NSView!

    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        let selectedChildController = lastBinding.latestOutput { $0.existingCredential }
            .map { $0 != nil }
            .skipRepeats()
            .observe(on: UIScheduler())
            .map {[unowned self] hasCred in hasCred ? self.loggedInViewController : self.loginViewController }

        containerView.uniqueSubview <~ selectedChildController.map { $0.view }
    }
}
