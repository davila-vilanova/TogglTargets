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


class AccountViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        existingCredential: SignalProducer<TogglAPITokenCredential?, NoError>,
        resolvedCredential: BindingTarget<TogglAPITokenCredential?>,
        testURLSessionAction: TestURLSessionAction)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Contained view controllers

    private lazy var loginViewController: LoginViewController = {
        let loginController = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("LoginViewController")) as! LoginViewController
        loginController <~ lastBinding.producer.skipNil().map { (credentialUpstream: $0.resolvedCredential,
                                                                 testURLSessionAction: $0.testURLSessionAction) }
        addChildViewController(loginController)
        return loginController
    }()

    private lazy var loggedInViewController: LoggedInViewController = {
        let loggedInController = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("LoggedInViewController")) as! LoggedInViewController
        let validBindings = lastBinding.producer.skipNil()
        let logOutRequested = MutableProperty<Void>(())
        logOutRequested.signal.map { nil as TogglAPITokenCredential? }.bindOnlyToLatest(validBindings.map { $0.resolvedCredential })
        loggedInController <~ validBindings.map { (existingCredential: $0.existingCredential,
                                                   testURLSessionAction: $0.testURLSessionAction,
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
