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

class LoginMethodViewController: NSTabViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = BindingTarget<TogglAPICredential?>

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Contained view controllers

    private enum ContainedControllerType: Int {
        case token = 0
        case emailPassword = 1

        static func from(_ controller: NSViewController) -> ContainedControllerType? {
            if controller as? APITokenViewController != nil {
                return .token
            } else if controller as? EmailPasswordViewController != nil {
                return .emailPassword
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

        let credentialsUpstream = lastBinding.producer.skipNil()
        if let tokenController = controller as? APITokenViewController {
            let switchToEmailPasswordController =
                reactive.makeBindingTarget { (me, _: ()) in me.selectedTabViewItemIndex = ContainedControllerType.emailPassword.rawValue }
            tokenController <~ credentialsUpstream.map { ($0, switchToEmailPasswordController) }
        } else if let emailPasswordController = controller as? EmailPasswordViewController {
            let switchToTokenController =
                reactive.makeBindingTarget { (me, _: ()) in me.selectedTabViewItemIndex = ContainedControllerType.token.rawValue }
            emailPasswordController <~ credentialsUpstream.map { ($0, switchToTokenController) }
        }
    }
}
