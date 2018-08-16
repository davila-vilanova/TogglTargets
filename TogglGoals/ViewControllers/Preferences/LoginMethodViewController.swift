//
//  LoginMethodViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 11.08.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class LoginMethodViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = BindingTarget<TogglAPICredential?>

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Contained view controllers

    private lazy var tokenViewController: APITokenViewController = {
        let tokenController = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("APITokenViewController")) as! APITokenViewController

        tokenController <~ SignalProducer
            .combineLatest(lastBinding.producer.skipNil(),
                           SignalProducer(value: switchToEmailPasswordController.bindingTarget))
            .map { (credentialUpstream: $0, switchToEmailPasswordEntry: $1) }

        addChildViewController(tokenController)

        return tokenController
    }()

    private lazy var emailPasswordViewController: EmailPasswordViewController = {
        let emailPasswordController = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("EmailPasswordViewController")) as! EmailPasswordViewController

        emailPasswordController <~ SignalProducer
            .combineLatest(lastBinding.producer.skipNil(),
                           SignalProducer(value: switchToTokenController.bindingTarget))
            .map { (credentialUpstream: $0, switchToDirectTokenEntry: $1) }

        addChildViewController(emailPasswordController)

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