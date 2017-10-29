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

fileprivate enum CredentialValidationResult {
    case valid(TogglAPITokenCredential, Profile)
    case invalid
    /// Error other than authentication error
    case error(APIAccessError)
}

class LoginViewController: NSViewController, ViewControllerContaining {

    // MARK: - Exposed reactive interface

    internal var userDefaults: BindingTarget<UserDefaults> { return _userDefaults.deoptionalizedBindingTarget }

    internal lazy var resolvedCredential: Signal<TogglAPITokenCredential, NoError> =
        credentialValidatingAction.values.map { validationResult -> TogglAPITokenCredential? in
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

    private let credentialProvider = MutableProperty<Signal<TogglAPICredential?, NoError>?>(nil)

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


    // MARK: - Credential Validation

    private lazy var credentialValidatingAction: Action<TogglAPICredential, CredentialValidationResult, NoError> = {
        let credential = credentialProvider.producer.skipNil().flatten(.latest)
        let validationEnabled: Property<Bool> = {
            let enabled = MutableProperty<Bool>(false)
            enabled <~ credential.map { $0 != nil }
            return Property(capturing: enabled)
        }()

        let action = Action<TogglAPICredential, CredentialValidationResult, NoError>(
            state: validationEnabled,
            enabledIf: { $0 },
            execute: { (_, credential) -> SignalProducer<CredentialValidationResult, NoError> in
                let session = URLSession(togglAPICredential: credential)
                // profileProducer generates a single value of type profile or triggers an error
                let profileProducer = session.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)
                // profileOrErrorProducer generates a single value of type Result that can contain a profile value or an error
                let profileOrErrorProducer = profileProducer.materialize().map { event -> Result<Profile, APIAccessError>? in
                    switch event {
                    case let .value(val): return Result<Profile, APIAccessError>(value: val)
                    case let .failed(err): return Result<Profile, APIAccessError>(error: err)
                    default: return nil
                    }
                    }
                    .skipNil()

                return profileOrErrorProducer.map { (result) -> CredentialValidationResult in
                    switch result {
                    case let .success(profile): return CredentialValidationResult.valid(TogglAPITokenCredential(apiToken: profile.apiToken!)!, profile)
                    case .failure(.authenticationError): return CredentialValidationResult.invalid
                    case let .failure(apiAccessError): return CredentialValidationResult.error(apiAccessError)
                    }
                }
        })

        action <~ credential.skipNil()

        return action
    }()

    private lazy var displaySpinner =
        BindingTarget<Bool>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (spin: Bool) -> Void in
            if spin {
                self.progressIndicator.startAnimation(nil)
            } else {
                self.progressIndicator.stopAnimation(nil)
            }
    }

    private lazy var dimLoginResult =
        BindingTarget<Bool>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (dim: Bool) -> Void in
            if dim {
                self.profileImageView.applyGaussianBlur()
                self.resultLabel.textColor = NSColor.gray
            } else {
                self.resultLabel.textColor = NSColor.black
            }
    }


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
        displayViewForLoginMethod <~ loginMethodFromButton // This will only fire when the user themselves select a login method from the popup menu
        persistLoginMethod <~ _userDefaults.producer.skipNil().combineLatest(with: loginMethodFromButton)


        resultLabel.reactive.stringValue <~ credentialValidatingAction.values.map { (result) -> String in
            switch result {
            case let .valid(_, profile): return "Hello, \(profile.name ?? "there") :)"
            case .invalid: return "Credential is not valid :("
            case let .error(err): return "Cannot verify -- \(err)"
            }
        }

        profileImageView.reactive.image <~ credentialValidatingAction.values.map { (result) -> NSImage? in
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

        displaySpinner <~ credentialValidatingAction.isExecuting
        dimLoginResult <~ credentialValidatingAction.isExecuting
    }
}

fileprivate protocol CredentialProducing {
    var credentialUpstream: Signal<TogglAPICredential?, NoError> { get }
}

fileprivate let DummyPassword = "***************"

class EmailPasswordViewController: NSViewController, CredentialProducing {

    // MARK: - Reactive interface and backing

    lazy private(set) var credentialUpstream = Property(_credentialUpstream).signal.map { $0 as TogglAPICredential? }
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
        _credentialUpstream <~ SignalProducer.combineLatest(usernameField.reactive.stringValues,
                                                            passwordField.reactive.stringValues,
                                                            changeInPassword.take(first: 1))
            .map { (email, password, _) in TogglAPIEmailCredential(email: email, password: password) }
    }
}

class APITokenViewController: NSViewController, CredentialProducing {

    // MARK: - Reactive interface and backing

    lazy private(set) var credentialUpstream = Property(_credentialUpstream).signal.map { $0 as TogglAPICredential? }
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
            .map { TogglAPITokenCredential(apiToken: $0) }
    }
}

fileprivate extension NSImageView {
    func applyGaussianBlur() {
        guard let original = self.image,
            let tiff = original.tiffRepresentation,
            let ciImage = CIImage(data: tiff),
            let filter = CIFilter(name: "CIGaussianBlur", withInputParameters: ["inputImage": ciImage]),
            let output = filter.outputImage else {
            return
        }
        let result = NSImage(size: original.size)
        result.lockFocus()
        output.draw(at: NSPoint.zero,
                    from: NSRect(origin: NSPoint.zero, size: result.size),
                    operation: NSCompositingOperation.destinationAtop,
                    fraction: 1.0)
        result.unlockFocus()
        self.image = result
    }
}
