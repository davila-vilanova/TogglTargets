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


class AccountViewController: NSTabViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        existingCredential: SignalProducer<TogglAPITokenCredential?, NoError>,
        resolvedCredential: BindingTarget<TogglAPITokenCredential?>,
        testURLSessionAction: TestURLSessionAction)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Contained view controllers

    private enum ContainedControllerType: Int {
        case login = 0
        case loggedIn = 1

        static func from(_ controller: NSViewController) -> ContainedControllerType? {
            if controller as? LoginViewController != nil {
                return .login
            } else if controller as? LoggedInViewController != nil {
                return .loggedIn
            } else {
                return nil
            }
        }
    }


    private var connectedControllerTypes = Set<ContainedControllerType>()

    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)

        guard let controller = tabViewItem?.viewController,
            let type = ContainedControllerType.from(controller),
            !connectedControllerTypes.contains(type) else {
                return
        }

        connectedControllerTypes.insert(type)

        let validBindings = lastBinding.producer.skipNil()

        if let loginController = controller as? LoginViewController {
            loginController <~ validBindings.map { (credentialUpstream: $0.resolvedCredential,
                                                        testURLSessionAction: $0.testURLSessionAction) }
        } else if let loggedInController = controller as? LoggedInViewController {
            let logOutRequested = MutableProperty<Void>(())
            logOutRequested.signal.map { nil as TogglAPITokenCredential? }.bindOnlyToLatest(validBindings.map { $0.resolvedCredential })
            loggedInController <~ validBindings.map { (existingCredential: $0.existingCredential,
                                                       testURLSessionAction: $0.testURLSessionAction,
                                                       logOut: logOutRequested.bindingTarget) }
        }
    }


    // MARK: - Wiring

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        reactive.makeBindingTarget {
            $0.selectedTabViewItemIndex = $1 } <~ lastBinding.latestOutput { $0.existingCredential }
                .map {
                    ($0 == nil) ? ContainedControllerType.login.rawValue : ContainedControllerType.loggedIn.rawValue }
    }
}
