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


fileprivate enum CredentialValidationResult {
    case valid(TogglAPITokenCredential, Profile)
    case invalid
    /// Error other than authentication error
    case error(APIAccessError)
    /// internal inconsistency, should not happen
    case other
}

class LoginViewController: NSViewController, ViewControllerContaining, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        existingAPIToken: SignalProducer<TogglAPITokenCredential, NoError>,
        resolvedCredential: BindingTarget<TogglAPITokenCredential>,
        testURLSessionAction: TestURLSessionAction)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


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

    @IBOutlet weak var credentialsView: NSView!
    @IBOutlet weak var loginButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var resultLabel: NSTextField!
    @IBOutlet weak var profileImageView: NSImageView!



    // MARK: - Wiring

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [UsernamePasswordVCContainment, APITokenVCContainment])

        func displaySelectedChildViewController(_ selectedController: NSViewController, in targetView: NSView) {
            displayController(selectedController, in: self.credentialsView)
            //            if let keyViewsProvidingViewController = selectedController as? KeyViewsProviding {
            //                self.loginMethodButton.nextKeyView = keyViewsProvidingViewController.firstKeyView
            //                keyViewsProvidingViewController.lastKeyView.nextKeyView = self.loginButton
            //            }
        }

        let displayEmailPasswordViewController = BindingTarget<Void>(on: UIScheduler(), lifetime: lifetime) { [unowned self] in
            displaySelectedChildViewController(self.emailPasswordViewController, in: self.credentialsView)
        }

        let displayTokenViewController = BindingTarget<Void>(on: UIScheduler(), lifetime: lifetime) { [unowned self] in
            displaySelectedChildViewController(self.apiTokenViewController, in: self.credentialsView)
        }

        let userEnteredEmail = MutableProperty<String?>(nil)
        let userEnteredPassword = MutableProperty<String?>(nil)
        let userEnteredToken = MutableProperty<String?>(nil)

        apiTokenViewController <~ SignalProducer(
            value: (tokenDownstream: lastBinding.latestOutput { $0.existingAPIToken }.map { $0.apiToken },
                    tokenUpstream: userEnteredToken.bindingTarget,
                    switchToTokenRetrievalFromEmailCredentials: displayEmailPasswordViewController))

        emailPasswordViewController <~ SignalProducer(
            value: (emailUpstream: userEnteredEmail.bindingTarget,
                    passwordUpstream: userEnteredPassword.bindingTarget,
                    switchToDirectTokenEntry: displayTokenViewController))

        let credentialFromUserEnteredAPIToken = MutableProperty<TogglAPITokenCredential?>(nil)
        let credentialFromUserEnteredEmail = MutableProperty<TogglAPIEmailCredential?>(nil)

        let credentialFromUserEnteredData = SignalProducer.merge(
            credentialFromUserEnteredAPIToken.producer.map { $0 as TogglAPICredential? },
            credentialFromUserEnteredEmail.producer.map { $0 as TogglAPICredential? })

        typealias ValidateCredentialActionState = (TogglAPICredential, TestURLSessionAction)
        let validateCredentialActionState = Property<ValidateCredentialActionState?>(
            initial: nil,
            then: SignalProducer.combineLatest(credentialFromUserEnteredData, lastBinding.producer.map { $0?.testURLSessionAction })
                .map { them -> ValidateCredentialActionState? in (them.0 == nil || them.1 == nil) ? nil : (them.0!, them.1!) })

        let validateCredential = Action<Void, CredentialValidationResult, NoError>(
            unwrapping: validateCredentialActionState,
            execute: { (state: ValidateCredentialActionState) -> SignalProducer<CredentialValidationResult, NoError> in
                let (credential, testURLSessionAction) = state
                let session = URLSession(togglAPICredential: credential)

                // profileProducer generates a single value of type profile or triggers an error
                let profileProducer = testURLSessionAction.apply(session)

                // profileOrErrorProducer generates a single value of type Result that can contain a profile value or an error
                let profileOrErrorProducer = profileProducer.materialize().map { event -> Result<Profile, ActionError<APIAccessError>>? in
                    switch event {
                    case let .value(val): return Result(value: val)
                    case let .failed(err): return Result(error: err)
                    default: return nil
                    }
                }.skipNil()

                return profileOrErrorProducer.map { (result) -> CredentialValidationResult in
                    switch result {
                    case let .success(profile): return CredentialValidationResult.valid(TogglAPITokenCredential(apiToken: profile.apiToken!)!, profile)
                    case .failure(.disabled): return CredentialValidationResult.other // should never run if inner action disabled
                    case .failure(.producerFailed(.authenticationError)): return CredentialValidationResult.invalid
                    case let .failure(.producerFailed(apiAccessError)): return CredentialValidationResult.error(apiAccessError)
                    }
                }
        })

        loginButton.reactive.pressed = CocoaAction(validateCredential)

        let resolvedCredential: Signal<TogglAPITokenCredential, NoError> =
            validateCredential.values.map { validationResult -> TogglAPITokenCredential? in
                switch validationResult {
                case let .valid(credential, _): return credential
                default: return nil
                }
            }.skipNil()

        lifetime.observeEnded {
            _ = resolvedCredential
        }

        lifetime += resolvedCredential.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.resolvedCredential })

        resultLabel.reactive.stringValue <~ validateCredential.values.map { (result) -> String in
            switch result {
            case let .valid(_, profile): return "Hello, \(profile.name ?? "there") :)"
            case .invalid: return "Credential is not valid :("
            case let .error(err): return "Cannot verify -- \(err)"
            case .other: return "Cannot verify"
            }
        }

        profileImageView.reactive.image <~ validateCredential.values.map { (result) -> NSImage? in
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

        let displaySpinner =
            BindingTarget<Bool>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (spin: Bool) -> Void in
                if spin {
                    self.progressIndicator.startAnimation(nil)
                } else {
                    self.progressIndicator.stopAnimation(nil)
                }
        }

        let dimLoginResult =
            BindingTarget<Bool>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (dim: Bool) -> Void in
                if dim {
                    self.profileImageView.animator().applyGaussianBlur()
                    self.resultLabel.textColor = NSColor.gray
                } else {
                    self.resultLabel.textColor = NSColor.black
                }
        }

        displaySpinner <~ validateCredential.isExecuting
        dimLoginResult <~ validateCredential.isExecuting

        // Start by displaying token VC

        displayTokenViewController <~ SignalProducer(value: ())
    }
    // MARK: -
}

fileprivate protocol KeyViewsProviding {
    var firstKeyView: NSView { get }
    var lastKeyView: NSView { get }
}

// MARK: -

class EmailPasswordViewController: NSViewController, KeyViewsProviding, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        emailUpstream: BindingTarget<String?>,
        passwordUpstream: BindingTarget<String?>,
        switchToDirectTokenEntry: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Outlets and Action

    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!

    @IBAction func requestSwitchToTokenViewController(sender: AnyObject) {
        requestDirectTokenEntry <~ SignalProducer(value: ())
    }

    // MARK: - KeyViewsProviding

    var firstKeyView: NSView { return usernameField }
    var lastKeyView: NSView { return passwordField }


    // MARK: -

    private let (lifetime, token) = Lifetime.make()
    private let requestDirectTokenEntry = MutableProperty<Void>(())

    override func viewDidLoad() {
        super.viewDidLoad()

        let emailUpstream = MutableProperty<String?>(nil)
        let passwordUpstream = MutableProperty<String?>(nil)

        emailUpstream <~ usernameField.reactive.stringValues
        passwordUpstream <~ passwordField.reactive.stringValues

        let validBindings = lastBinding.producer.skipNil()
        emailUpstream.bindOnlyToLatest(validBindings.map { $0.emailUpstream })
        passwordUpstream.bindOnlyToLatest(validBindings.map { $0.passwordUpstream })
        requestDirectTokenEntry.bindOnlyToLatest(validBindings.map { $0.switchToDirectTokenEntry })
    }
}

// MARK: -

class APITokenViewController: NSViewController, KeyViewsProviding, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        tokenDownstream: SignalProducer<String, NoError>,
        tokenUpstream: BindingTarget<String?>,
        switchToTokenRetrievalFromEmailCredentials: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Outlet and Action

    @IBOutlet weak var apiTokenField: NSTextField!

    @IBAction func requestSwitchToEmailViewController(sender: AnyObject) {
        requestSwitchToTokenRetrieval <~ SignalProducer(value: ())
    }

    // MARK: - KeyViewsProviding

    var firstKeyView: NSView { return apiTokenField }
    var lastKeyView: NSView { return apiTokenField }


    // MARK: - Wiring

    private let (lifetime, token) = Lifetime.make()
    private let requestSwitchToTokenRetrieval = MutableProperty<Void>(())

    override func viewDidLoad() {
        super.viewDidLoad()

        let tokenDownstream = lastBinding.latestOutput { $0.tokenDownstream }
        let tokenUpstream = MutableProperty<String?>(nil)

        let textFieldOutput = apiTokenField.reactive.stringValues
        apiTokenField.reactive.stringValue <~ tokenDownstream.take(first: 1).take(until: textFieldOutput.map { _ in () })
        tokenUpstream <~ textFieldOutput

        let validBindings = lastBinding.producer.skipNil()
        tokenUpstream.bindOnlyToLatest(validBindings.map { $0.tokenUpstream })
        requestSwitchToTokenRetrieval.bindOnlyToLatest(validBindings.map { $0.switchToTokenRetrievalFromEmailCredentials })
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
