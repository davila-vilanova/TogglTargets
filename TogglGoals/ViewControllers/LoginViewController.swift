//
//  LoginViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

fileprivate let UsernamePasswordVCContainment = "UsernamePasswordVCContainment"
fileprivate let APITokenVCContainment = "APITokenVCContainment"

fileprivate enum LoginMethod: Int {
    case username
    case apiToken
}

class LoginViewController: NSViewController, ViewControllerContaining {

    // MARK: - Contained view controllers

    private var usernamePasswordViewController: UsernamePasswordViewController!
    private var apiTokenViewController: APITokenViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let vc = controller as? UsernamePasswordViewController {
            usernamePasswordViewController = vc
        } else if let vc = controller as? APITokenViewController {
            apiTokenViewController = vc
        }
    }

    // MARK: - Outlets

    @IBOutlet weak var loginMethodButton: NSPopUpButton!
    @IBOutlet weak var loginMethodUsernameItem: NSMenuItem!
    @IBOutlet weak var loginMethodAPITokenItem: NSMenuItem!
    @IBOutlet weak var credentialsView: NSView!
    @IBOutlet weak var testCredentialsButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var resultLabel: NSTextField!



    // MARK: -

    private let (lifetime, token) = Lifetime.make()
    private lazy var loginMethod = BindingTarget<LoginMethod>(on: UIScheduler(), lifetime: lifetime) { [unowned self] method in
        switch (method) {
        case .username:
            displayController(self.usernamePasswordViewController, in: self.credentialsView)
        case .apiToken:
            displayController(self.apiTokenViewController, in: self.credentialsView)
        }
    }

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeControllerContainment(containmentIdentifiers: [UsernamePasswordVCContainment, APITokenVCContainment])

        loginMethod <~ loginMethodButton.reactive.selectedItems.map { [loginMethodUsernameItem, loginMethodAPITokenItem] (item) -> LoginMethod in
            switch item {
            case loginMethodUsernameItem!: return .username
            case loginMethodAPITokenItem!: return .apiToken
            default: return .apiToken
            }
        }

        loginMethodButton.select(loginMethodUsernameItem)
    }
}

class UsernamePasswordViewController: NSViewController {
    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

}

class APITokenViewController: NSViewController {
    @IBOutlet weak var apiTokenField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

}
