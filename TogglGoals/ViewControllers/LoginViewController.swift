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
            case let .valid(credential, _): return credential
            default: return nil
            }
        }.skipNil()


    // MARK: - Backing of exposed reactive interface

    private var _userDefaults = MutableProperty<UserDefaults?>(nil)


    // MARK: - Contained view controllers

    private var emailPasswordViewController: EmailPasswordViewController! {
        didSet {
            emailPasswordViewController.userDefaults <~ _userDefaults.producer.skipNil()
        }
    }
    private var apiTokenViewController: APITokenViewController! {
        didSet {
            apiTokenViewController.userDefaults <~ _userDefaults.producer.skipNil()
        }
    }

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
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var resultLabel: NSTextField!
    @IBOutlet weak var profileImageView: NSImageView!


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
            case let .valid(_, profile): return "Hello, \(profile.name ?? "there") :)"
            case .invalid: return "Credential is not valid :("
            case let .error(err): return "Cannot verify -- \(err)"
            }
        }

        let startProgressIndication = progressIndicator.reactive.makeBindingTarget(on: UIScheduler()) { (indicator, _: ()) -> Void in
            indicator.startAnimation(nil)
        }
        let stopProgressIndication = progressIndicator.reactive.makeBindingTarget(on: UIScheduler()) { (indicator, _: ()) in
            indicator.stopAnimation(nil)
        }
        startProgressIndication <~ credentialProvider.producer.skipNil().flatten(.latest).map { _ in () }
        stopProgressIndication <~ credentialValidator.validationResult.map { _ in () }

        profileImageView.reactive.image <~ credentialValidator.validationResult.map { (result) -> NSImage? in
            switch result {
            case let .valid(_, profile):
                if let imageURL = profile.imageUrl {
                    let image = NSImage(contentsOf: imageURL)
                    return image
                } else {
                    return nil
                }
            default: return nil
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

fileprivate let DummyPassword = "***************"

class EmailPasswordViewController: NSViewController, CredentialProducing {

    // MARK: - Reactive interface and backing

    lazy private(set) var credentialUpstream = Property(_credentialUpstream).signal.skipNil().map { $0 as TogglAPICredential }
    private let _credentialUpstream = MutableProperty<TogglAPIEmailCredential?>(nil)

    var userDefaults: BindingTarget<UserDefaults> { return _userDefaults.deoptionalizedBindingTarget }
    private var _userDefaults = MutableProperty<UserDefaults?>(nil)


    // MARK: - Outlets

    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!


    // MARK: -

    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()

    private lazy var persistEmailAddress =
        BindingTarget<(UserDefaults, String)>(on: scheduler, lifetime: lifetime) { (userDefaults, email) in
            userDefaults.set(email, forKey: PersistenceKeys.lastEnteredEmailAddress.rawValue)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let persistedEmailAddress = _userDefaults.producer.skipNil()
            .map { $0.string(forKey: PersistenceKeys.lastEnteredEmailAddress.rawValue) }
            .map { $0 ?? "" }

        usernameField.reactive.stringValue <~ persistedEmailAddress.take(first: 1)
        passwordField.reactive.stringValue <~ persistedEmailAddress.take(first: 1)
                .map { $0.count > 0 ? DummyPassword : "" }

        let changeInEmailAddress = SignalProducer.combineLatest(usernameField.reactive.stringValues,
                                                                persistedEmailAddress.take(first: 1))
            .filter { (inField, persisted) in inField != persisted }
            .map { _ in return () }

        let changeInPassword = passwordField.reactive.stringValues
            .filter { $0 != DummyPassword }
            .map { _ in return () }

        // Clear password field's contents the first time the email address differs from the persisted one,
        // except if the password has changed already
        passwordField.reactive.stringValue <~ changeInEmailAddress
            .take(first: 1)
            .take(until: changeInPassword)
            .map { _ in return "" }

        persistEmailAddress <~ _userDefaults.producer.skipNil().combineLatest(with: usernameField.reactive.stringValues.skipRepeats())

        // Generate credentials only from the moment the user has entered a password onwards
        _credentialUpstream <~ SignalProducer.combineLatest(usernameField.reactive.stringValues.filter(nonEmpty),
                                                            passwordField.reactive.stringValues.filter(nonEmpty),
                                                            changeInPassword.take(first: 1))
            .map { (email, password, _) in TogglAPIEmailCredential(email: email, password: password) }
            .skipRepeats()
            .logEvents()
    }

}

class APITokenViewController: NSViewController, CredentialProducing {

    // MARK: - Reactive interface and backing

    lazy private(set) var credentialUpstream = Property(_credentialUpstream).signal.skipNil().map { $0 as TogglAPICredential }
    private let _credentialUpstream = MutableProperty<TogglAPITokenCredential?>(nil)

    var userDefaults: BindingTarget<UserDefaults> { return _userDefaults.deoptionalizedBindingTarget }
    private var _userDefaults = MutableProperty<UserDefaults?>(nil)


    // MARK: - Outlets

    @IBOutlet weak var apiTokenField: NSTextField!


    // MARK: -

    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()

    private lazy var persistAPIToken =
        BindingTarget<(UserDefaults, String)>(on: scheduler, lifetime: lifetime) { (userDefaults, token) in
            userDefaults.set(token, forKey: PersistenceKeys.lastEnteredAPIToken.rawValue)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let persistedAPIToken = _userDefaults.producer.skipNil()
            .map { $0.string(forKey: PersistenceKeys.lastEnteredAPIToken.rawValue) }
            .map { $0 ?? "" }

        apiTokenField.reactive.stringValue <~ persistedAPIToken.take(first: 1)
        persistAPIToken <~ _userDefaults.producer.skipNil().combineLatest(with: apiTokenField.reactive.stringValues.skipRepeats())

        _credentialUpstream <~ apiTokenField.reactive.stringValues
            .filter(nonEmpty)
            .map { TogglAPITokenCredential(apiToken: $0) }
            .skipRepeats()
    }
}
