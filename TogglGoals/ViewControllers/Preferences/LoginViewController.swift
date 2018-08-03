//
//  LoginViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 01.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

fileprivate let APITokenVCContainment = "APITokenVCContainment"
fileprivate let UsernamePasswordVCContainment = "UsernamePasswordVCContainment"

fileprivate enum CredentialValidationResult {
    case valid(TogglAPITokenCredential, Profile)
    case invalid
    /// Error other than authentication error
    case error(APIAccessError)
    /// internal inconsistency, should not happen
    case other

    var isError: Bool {
        switch (self) {
        case .error: return true
        case .other: return true
        default: return false
        }
    }
}

class LoginViewController: NSViewController, ViewControllerContaining, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        resolvedCredential: BindingTarget<TogglAPITokenCredential?>,
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
    @IBOutlet weak var errorField: NSTextField!

    private let credentialFromToken = MutableProperty<TogglAPICredential?>(nil)
    private let credentialFromEmail = MutableProperty<TogglAPICredential?>(nil)
    private let selectedCredentialSource = MutableProperty<SignalProducer<TogglAPICredential?, NoError>?>(nil)
    private lazy var credentialFromUserEnteredData = selectedCredentialSource.producer.skipNil().flatten(.latest)
    private let displayTokenViewController = MutableProperty<Void>(())
    private let displayEmailPasswordViewController = MutableProperty<Void>(())


    // MARK: - Wiring

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [APITokenVCContainment, UsernamePasswordVCContainment])


        // Connect interfaces of children controllers

        apiTokenViewController <~ SignalProducer(
            value: (credentialUpstream: credentialFromToken.bindingTarget,
                    switchToEmailPasswordController: displayEmailPasswordViewController.bindingTarget))

        emailPasswordViewController <~ SignalProducer(
            value: (credentialUpstream: credentialFromEmail.bindingTarget,
                    switchToTokenController: displayTokenViewController.bindingTarget))


        // Set up the displaying of the right view controller

        typealias SelectViewControllerInput = (NSViewController, SignalProducer<TogglAPICredential?, NoError>)

        let selectedViewControllerInput = MutableProperty<SelectViewControllerInput?>(nil)
        lifetime.observeEnded {
            _ = selectedViewControllerInput
        }
        setupContainment(of: selectedViewControllerInput.producer.skipNil().map { $0.0 }, in: self, view: self.credentialsView)

        self.loginButton.reactive.makeBindingTarget { button, controller in
            if let keyViewsProvider = controller as? KeyViewsProviding {
                keyViewsProvider.lastKeyView.nextKeyView = button
            }
        } <~ selectedViewControllerInput.producer.skipNil().map { $0.0 }

        selectedCredentialSource <~ selectedViewControllerInput.producer.skipNil().map { $0.1 }


        // Token controller is displayed by default, email+password upon request
        // Take producer from displayTokenViewController and signal from displayEmailPasswordViewController
        selectedViewControllerInput <~ displayTokenViewController.producer.map { [unowned self] _ -> SelectViewControllerInput in (self.apiTokenViewController, self.credentialFromToken.producer) }
        selectedViewControllerInput <~ displayEmailPasswordViewController.signal.map { [unowned self] _ -> SelectViewControllerInput in (self.emailPasswordViewController, self.credentialFromEmail.producer) }


        // Set up validation of credentials entered by the user
        // (token or email+password, converted to token upon succesful validation)
        // when login button is pressed
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
        loginButton.reactive.makeBindingTarget {
            $0.title = $1
        } <~ validateCredential.values.filter { $0.isError }.map { _ in
            NSLocalizedString("login.loginButton.retry", comment: "login button's title inviting to retry after login fails")
        }


        // Take validated / resolved token credential from action's output
        // and connect it to credential output

        let resolvedCredential: Signal<TogglAPITokenCredential?, NoError> =
            validateCredential.values.map { validationResult -> TogglAPITokenCredential? in
                switch validationResult {
                case let .valid(credential, _): return credential
                default: return nil
                }
            }

        resolvedCredential.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.resolvedCredential })


        // Show activity while validating credential

        let displaySpinner =
            BindingTarget<Bool>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (spin: Bool) -> Void in
                if spin {
                    self.progressIndicator.startAnimation(nil)
                } else {
                    self.progressIndicator.stopAnimation(nil)
                }
        }

        displaySpinner <~ validateCredential.isExecuting


        // Provide feedback after credential validated

        errorField.reactive.stringValue <~ validateCredential.values.map { (result) -> String in
            switch result {
            case .valid(_, _):
                return ""
            case .invalid:
                return NSLocalizedString("login.error.invalid-credential", comment: "login error: invalid credential")
            case let .error(err):
                return String.localizedStringWithFormat(
                    NSLocalizedString("login.error.cannot-verify",
                                      comment: "login error: cannot verify credential due to underlying error"),
                    localizedDescription(for: err))
            case .other:
                return NSLocalizedString("login.error.cannot-verify.unexpected",
                                         comment: "login error: cannot verify credential due to unexpected error")
            }
        }
    }
}
