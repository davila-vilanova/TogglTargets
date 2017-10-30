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
    /// internal inconsistency, should not happen
    case other
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
    @IBOutlet weak var loginButton: NSButton! {
        didSet {
            guard let button = loginButton else {
                return
            }
            button.reactive.pressed = CocoaAction(credentialValidatingAction) { _ in () }
        }
    }
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

            let fittingHeight = selectedController.view.fittingSize.height
            let currentHeight = self.credentialsView.frame.height
            let diff = fittingHeight - currentHeight
            if let window = self.view.window {
                var newFrame = window.frame
                newFrame.size.height += diff
                newFrame.origin.y -= diff
                window.setFrame(newFrame, display: true, animate: true)
            }

            displayController(selectedController, in: self.credentialsView)
            if let credentialProducingController = selectedController as? CredentialProducing {
                self.credentialProvider <~ SignalProducer(value: credentialProducingController.credentialUpstream)
            } else {
                fatalError("Selected a controller that does not produce credentials: \(selectedController)")
            }
            if let keyViewsProvidingViewController = selectedController as? KeyViewsProviding {
                self.loginMethodButton.nextKeyView = keyViewsProvidingViewController.firstKeyView
                keyViewsProvidingViewController.lastKeyView.nextKeyView = self.loginButton
            }
    }

    private let credentialProvider = MutableProperty<SignalProducer<TogglAPICredential?, NoError>?>(nil)

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

    private lazy var credentialValidatingAction: Action<(), CredentialValidationResult, NoError> = {
        let credential = credentialProvider.producer.skipNil().flatten(.latest)

        let latestSeenCredential: Property<TogglAPICredential?> = {
            let p = MutableProperty<TogglAPICredential?>(nil)
            p <~ credential
            return Property(capturing: p)
        }()

        return Action<(), CredentialValidationResult, NoError>(
            state: latestSeenCredential,
            enabledIf: { $0 != nil },
            execute: { (credentialOrNil, _) -> SignalProducer<CredentialValidationResult, NoError> in
                guard let credential = credentialOrNil else {
                    assert(false, "credential should not be nil if the action is enabled")
                    return SignalProducer(value: CredentialValidationResult.other)
                }
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
                self.profileImageView.animator().applyGaussianBlur()
                self.resultLabel.textColor = NSColor.gray
            } else {
                self.resultLabel.textColor = NSColor.black
            }
    }


    // MARK: - View did load
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
            case .other: return "Cannot verify"
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
    // MARK: -
}

fileprivate protocol CredentialProducing {
    var credentialUpstream: SignalProducer<TogglAPICredential?, NoError> { get }
}

fileprivate protocol KeyViewsProviding {
    var firstKeyView: NSView { get }
    var lastKeyView: NSView { get }
}

class EmailPasswordViewController: NSViewController, CredentialProducing, KeyViewsProviding {

    // MARK: - Reactive interface and backing

    lazy private(set) var credentialUpstream = Property(_credentialUpstream).producer.map { $0 as TogglAPICredential? }
    private let _credentialUpstream = MutableProperty<TogglAPIEmailCredential?>(nil)

    var userDefaults: BindingTarget<UserDefaults> { return _userDefaults.deoptionalizedBindingTarget }
    private var _userDefaults = MutableProperty<UserDefaults?>(nil)


    // MARK: - Outlets

    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!


    // MARK: - KeyViewsProviding

    var firstKeyView: NSView { return usernameField }
    var lastKeyView: NSView { return passwordField }


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

        persistEmailAddress <~ _userDefaults.producer.skipNil().combineLatest(with: usernameField.reactive.stringValues.skipRepeats())

        _credentialUpstream <~ SignalProducer.combineLatest(
            persistedEmailAddress.take(untilReplacement: usernameField.reactive.continuousStringValues),
            passwordField.reactive.continuousStringValues)
            .map { TogglAPIEmailCredential(email: $0, password: $1) }
    }
}

class APITokenViewController: NSViewController, CredentialProducing, KeyViewsProviding {

    // MARK: - Reactive interface and backing

    lazy private(set) var credentialUpstream = Property(_credentialUpstream).producer.map { $0 as TogglAPICredential? }
    private let _credentialUpstream = MutableProperty<TogglAPITokenCredential?>(nil)

    var userDefaults: BindingTarget<UserDefaults> { return _userDefaults.deoptionalizedBindingTarget }
    private var _userDefaults = MutableProperty<UserDefaults?>(nil)


    // MARK: - Outlets

    @IBOutlet weak var apiTokenField: NSTextField!


    // MARK: - KeyViewsProviding

    var firstKeyView: NSView { return apiTokenField }
    var lastKeyView: NSView { return apiTokenField }


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
        persistAPIToken <~ _userDefaults.producer.skipNil()
            .combineLatest(with: apiTokenField.reactive.stringValues.skipRepeats())

        _credentialUpstream <~ persistedAPIToken.take(untilReplacement: apiTokenField.reactive.continuousStringValues)
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
