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

fileprivate enum PersistenceKeys: String {
    case selectedLoginMethod
    case lastEnteredEmailAddress
    case lastEnteredAPIToken
}

fileprivate enum LoginMethod: String {
    case email
    case apiToken
}

fileprivate let DefaultLoginMethod = LoginMethod.email

class LoginViewController: NSViewController, ViewControllerContaining {

    // MARK: - Exposed reactive interface

    internal var userDefaults: BindingTarget<UserDefaults> { return _userDefaults.deoptionalizedBindingTarget }

    internal lazy var resolvedCredential: Signal<TogglAPITokenCredential, NoError> =
        credentialValidator.validationResult.map { validationResult -> TogglAPITokenCredential? in
            switch validationResult {
            case let .valid(credential): return credential
            default: return nil
            }
        }.skipNil()


    // MARK: - Backing of exposed reactive interface

    private var _userDefaults = MutableProperty<UserDefaults?>(nil)


    // MARK: - Contained view controllers

    private var emailPasswordViewController: EmailPasswordViewController!
    private var apiTokenViewController: APITokenViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let vc = controller as? EmailPasswordViewController {
            emailPasswordViewController = vc
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
    private let scheduler = QueueScheduler()

    private lazy var displayViewForLoginMethod =
        BindingTarget<LoginMethod>(on: UIScheduler(), lifetime: lifetime) { [unowned self] loginMethod in
            let selectedController: NSViewController
            switch (loginMethod) {
            case .email:
                selectedController = self.emailPasswordViewController
            case .apiToken:
                selectedController = self.apiTokenViewController
            }
            displayController(selectedController, in: self.credentialsView)
            if let credentialProducingController = selectedController as? CredentialProducing {
                self.credentialProvider <~ SignalProducer(value: credentialProducingController.credentialUpstream)
            } else {
                fatalError("Selected a controller that does not produce credentials: \(selectedController)")
            }
    }

    private let credentialProvider = MutableProperty<Signal<TogglAPICredential, NoError>?>(nil)

    private lazy var selectLoginMethodButton =
        BindingTarget<LoginMethod>(on: UIScheduler(), lifetime: lifetime) { [unowned self] loginMethod in
            let selectedItem: NSMenuItem
            switch (loginMethod) {
            case .email:
                selectedItem = self.loginMethodUsernameItem
            case .apiToken:
                selectedItem = self.loginMethodAPITokenItem
            }
            self.loginMethodButton.select(selectedItem)
    }

    private lazy var persistLoginMethod =
        BindingTarget<(UserDefaults, LoginMethod)>(on: scheduler, lifetime: lifetime) { (userDefaults, loginMethod) in
            userDefaults.set(loginMethod.rawValue, forKey: PersistenceKeys.selectedLoginMethod.rawValue)
    }


    // MARK: -

    private lazy var credentialValidator = CredentialValidator()


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeControllerContainment(containmentIdentifiers: [UsernamePasswordVCContainment, APITokenVCContainment])

        let persistedLoginMethod = _userDefaults.producer.skipNil()
            .map { $0.string(forKey: PersistenceKeys.selectedLoginMethod.rawValue) }
            .map { methodOrNil -> LoginMethod in
                if let methodString = methodOrNil,
                    let method = LoginMethod(rawValue: methodString) {
                    return method
                }
                return DefaultLoginMethod
        }

        let loginMethodFromButton = loginMethodButton.reactive.selectedItems.map { [loginMethodUsernameItem, loginMethodAPITokenItem] (item) -> LoginMethod in
            switch item {
            case loginMethodUsernameItem!: return .email
            case loginMethodAPITokenItem!: return .apiToken
            default: return .apiToken
            }
        }

        displayViewForLoginMethod <~ persistedLoginMethod.take(first: 1)
        selectLoginMethodButton <~ persistedLoginMethod.take(first: 1)
        displayViewForLoginMethod <~ loginMethodFromButton // This will only fire when the user themselves hit the button
        persistLoginMethod <~ _userDefaults.producer.skipNil().combineLatest(with: loginMethodFromButton)

        credentialValidator.credential <~ credentialProvider.producer.skipNil().flatten(.latest)
        resultLabel.reactive.stringValue <~ credentialValidator.validationResult.map { (result) -> String in
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

fileprivate protocol CredentialProducing {
    var credentialUpstream: Signal<TogglAPICredential, NoError> { get }
}

class EmailPasswordViewController: NSViewController, CredentialProducing {
    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!

    lazy private(set) var credentialUpstream = Property(_credentialUpstream).signal.skipNil().map { $0 as TogglAPICredential }
    private let _credentialUpstream = MutableProperty<TogglAPIEmailCredential?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        _credentialUpstream <~ SignalProducer.combineLatest(usernameField.reactive.stringValues.filter(nonEmpty),
                                                           passwordField.reactive.stringValues.filter(nonEmpty))
            .map { TogglAPIEmailCredential(email: $0, password: $1) }
    }

}

class APITokenViewController: NSViewController, CredentialProducing {
    @IBOutlet weak var apiTokenField: NSTextField!

    lazy private(set) var credentialUpstream = Property(_credentialUpstream).signal.skipNil().map { $0 as TogglAPICredential }
    private let _credentialUpstream = MutableProperty<TogglAPITokenCredential?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        _credentialUpstream <~ apiTokenField.reactive.stringValues
            .filter(nonEmpty)
            .map { TogglAPITokenCredential(apiToken: $0) }
    }
}
