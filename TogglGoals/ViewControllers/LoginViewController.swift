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
import Result

fileprivate let UsernamePasswordVCContainment = "UsernamePasswordVCContainment"
fileprivate let APITokenVCContainment = "APITokenVCContainment"

fileprivate enum LoginMethod: Int {
    case email
    case apiToken
}

class LoginViewController: NSViewController, ViewControllerContaining {

    // MARK: - Exposed reactive interface

    internal var credential: BindingTarget<TogglAPITokenCredential?> { return _credential.bindingTarget }
    internal var userUpdates: Signal<TogglAPICredential?, NoError> { return _userUpdates.signal }
    internal var credentialValidationResult: BindingTarget<CredentialValidator.ValidationResult> { return _credentialValidationResult.deoptionalizedBindingTarget}


    // MARK: - Backing of reactive interface

    internal var _credential = MutableProperty<TogglAPITokenCredential?>(nil)
    internal var _userUpdates = MutableProperty<TogglAPICredential?>(nil)
    internal let _credentialValidationResult = MutableProperty<CredentialValidator.ValidationResult?>(nil)


    // MARK: - Contained view controllers

    private var usernamePasswordViewController: EmailPasswordViewController! {
        didSet {
            _userUpdates <~ usernamePasswordViewController.credentialUpstream.producer.skipNil().map { $0 as TogglAPICredential }
        }
    }
    private var apiTokenViewController: APITokenViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let vc = controller as? EmailPasswordViewController {
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
        case .email:
            displayController(self.usernamePasswordViewController, in: self.credentialsView)
            self.loginMethodButton.select(self.loginMethodUsernameItem)
        case .apiToken:
            displayController(self.apiTokenViewController, in: self.credentialsView)
            self.loginMethodButton.select(self.loginMethodAPITokenItem)
        }
    }


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeControllerContainment(containmentIdentifiers: [UsernamePasswordVCContainment, APITokenVCContainment])

        let loginMethodFromCredential = _credential
            .map { $0?.type }
            .map { (credential: CredentialType?) -> LoginMethod in
                switch credential {
                case .email?: return .email
                case .apiToken?: return .apiToken
                default: return .email
                }
        }

        let loginMethodFromButton = loginMethodButton.reactive.selectedItems.map { [loginMethodUsernameItem, loginMethodAPITokenItem] (item) -> LoginMethod in
            switch item {
            case loginMethodUsernameItem!: return .email
            case loginMethodAPITokenItem!: return .apiToken
            default: return .apiToken
            }
        }

        loginMethod <~ loginMethodFromCredential
        loginMethod <~ loginMethodFromButton

        resultLabel.reactive.stringValue <~ _credentialValidationResult.producer.skipNil().map { (result) -> String in
            switch result {
            case .valid: return "Credential is valid :)"
            case .invalid: return "Credential is not valid :("
            case let .error(err): return "Cannot verify -- \(err)"
            }
        }
    }
}

fileprivate func nonEmpty(_ string: String) -> Bool {
    return !string.isEmpty
}

class EmailPasswordViewController: NSViewController {
    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!

    lazy var credentialUpstream = Property(_credentialUpstream)
    private let _credentialUpstream = MutableProperty<TogglAPIEmailCredential?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        _credentialUpstream <~ SignalProducer.combineLatest(usernameField.reactive.stringValues.filter(nonEmpty),
                                                           passwordField.reactive.stringValues.filter(nonEmpty))
            .map { TogglAPIEmailCredential(email: $0, password: $1) }
    }

}

class APITokenViewController: NSViewController {
    @IBOutlet weak var apiTokenField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

}
