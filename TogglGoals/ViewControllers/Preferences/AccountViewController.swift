//
//  AccountViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

fileprivate let LogInVCContainment = "LogInVCContainment"
fileprivate let LoggedInVCContainment = "LoggedInVCContainment"

class AccountViewController: NSViewController, ViewControllerContaining, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        existingCredential: SignalProducer<TogglAPITokenCredential?, NoError>,
        resolvedCredential: BindingTarget<TogglAPITokenCredential?>,
        testURLSessionAction: TestURLSessionAction)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Contained view controllers

    private var loginViewController: LoginViewController!
    private var loggedInViewController: LoggedInViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let vc = controller as? LoginViewController {
            loginViewController = vc
        } else if let vc = controller as? LoggedInViewController {
            loggedInViewController = vc
        }
    }


    // MARK: - Wiring

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        initializeControllerContainment(containmentIdentifiers: [LogInVCContainment, LoggedInVCContainment])

        let validBindings = lastBinding.producer.skipNil()
        loginViewController <~ validBindings.map { (credentialUpstream: $0.resolvedCredential,
                                                    testURLSessionAction: $0.testURLSessionAction) }

        let logOutRequested = MutableProperty<Void>(())
        logOutRequested.signal.map { nil as TogglAPITokenCredential? }.bindOnlyToLatest(validBindings.map { $0.resolvedCredential })
        loggedInViewController <~ validBindings.map { (existingCredential: $0.existingCredential,
                                                       testURLSessionAction: $0.testURLSessionAction,
                                                       logOut: logOutRequested.bindingTarget) }

        let selectedController = lastBinding.latestOutput { $0.existingCredential }
            .map { [unowned self] (cred: TogglAPITokenCredential?) -> NSViewController in
                return (cred == nil) ? self.loginViewController : self.loggedInViewController
        }

        setupContainment(of: selectedController, in: self, view: self.view)
    }
}
