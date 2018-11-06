//
//  LoginViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 01.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

private enum CredentialValidationResult {
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

    var isValid: Bool {
        switch self {
        case .valid: return true
        default: return false
        }
    }
}

class LoginViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: Interface

    internal typealias Interface = (
        resolvedCredential: BindingTarget<TogglAPITokenCredential?>,
        testURLSessionAction: RetrieveProfileNetworkAction)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Contained view controllers

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let loginMethodController = segue.destinationController as? LoginMethodViewController {
            loginMethodController <~ SignalProducer(value: (
                credentialUpstream: credentialFromUserEnteredData.bindingTarget,
                attemptLogin: validateCredential.bindingTarget)
            )
        }
    }

    // MARK: - Outlets

    @IBOutlet weak var loginButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var errorField: NSTextField!

    // MARK: - Credential validation

    private lazy var validateCredential: Action<Void, CredentialValidationResult, NoError> = {
        typealias ValidateCredentialActionState = (TogglAPICredential, RetrieveProfileNetworkAction)
        let validateCredentialActionState = Property<ValidateCredentialActionState?>(
            initial: nil,
            then: SignalProducer.combineLatest(credentialFromUserEnteredData,
                                               lastBinding.producer.map { $0?.testURLSessionAction })
                .map { them -> ValidateCredentialActionState? in
                    (them.0 == nil || them.1 == nil) ? nil : (them.0!, them.1!) })

        let validateAction = Action<Void, CredentialValidationResult, NoError>(
            unwrapping: validateCredentialActionState,
            execute: { (state: ValidateCredentialActionState) -> SignalProducer<CredentialValidationResult, NoError> in
                let (credential, testURLSessionAction) = state
                let session = URLSession(togglAPICredential: credential)

                // profileProducer generates a single value of type profile or triggers an error
                let profileProducer = testURLSessionAction.apply(session)

                // profileOrErrorProducer generates a single value of type Result
                // that can contain a profile value or an error
                let profileOrErrorProducer = profileProducer.materialize()
                    .map { event -> Result<Profile, ActionError<APIAccessError>>? in
                        switch event {
                        case let .value(val): return Result(value: val)
                        case let .failed(err): return Result(error: err)
                        default: return nil
                        }
                    }.skipNil()

                return profileOrErrorProducer.map { (result) -> CredentialValidationResult in
                    switch result {
                    case let .success(profile):
                        return .valid(TogglAPITokenCredential(apiToken: profile.apiToken!)!, profile)
                    case .failure(.disabled): return .other // should never run if inner action disabled
                    case .failure(.producerFailed(.authenticationError)): return .invalid
                    case let .failure(.producerFailed(apiAccessError)): return .error(apiAccessError)
                    }
                }
        })

        return validateAction
    }()

    // MARK: - Wiring

    private lazy var credentialFromUserEnteredData = MutableProperty<TogglAPICredential?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up validation of credentials entered by the user
        // (token or email+password, converted to token upon succesful validation)
        // when login button is pressed

        loginButton.reactive.pressed = CocoaAction(validateCredential)
        loginButton.reactive.makeBindingTarget {
            $0.title = $1
        } <~ validateCredential.values.filter { $0.isError }.map { _ in
            NSLocalizedString("login.loginButton.retry",
                              comment: "login button's title inviting to retry after login fails")
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
            BindingTarget<Bool>(on: UIScheduler(), lifetime: reactive.lifetime) { [unowned self] (spin: Bool) -> Void in
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
            case .valid:
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

    // MARK: - Onboarding

    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, NoError>] {
        let credentialSuccessfullyValidated = validateCredential.values.filter { $0.isValid }.map { _ in () }
        let loginView = viewDidLoadProducer
            .map { [unowned self] in self.view }
            .concat(SignalProducer.never)
            .take(until: credentialSuccessfullyValidated)
        return [.login: loginView]
    }
}
