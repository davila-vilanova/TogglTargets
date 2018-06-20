//
//  ErrorViewController.swift
//  TogglGoals
//
//  Created by David Davila on 01.04.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

let ConfigureUserAccountRequestedNotificationName = NSNotification.Name(rawValue: "ConfigureUserAccountRequestedNotification")

private typealias RecoveryAction = Action<Void, Void, NoError>

class ErrorViewController: NSViewController {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var recoveryButton: NSButton!

    func displayError(_ error: APIAccessError, for activityDescription: String, retryAction: RetryAction) {
        representedError.value = (error, activityDescription, retryAction)
    }

    private let representedError = MutableProperty<(APIAccessError, String, RetryAction)?>(nil)
    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        let representedErrorProducer = representedError.producer.skipNil()

        titleLabel.reactive.text <~ representedErrorProducer.map { $0.1 }.map(errorTitle)
        descriptionLabel.reactive.text <~ representedErrorProducer.map { $0.0 }.map(localizedDescription)

        recoveryButton.reactive.makeBindingTarget(on: UIScheduler()) { (button, action) in
            button.reactive.pressed = action
            } <~ representedErrorProducer.map { ($0.0, $0.2) }
                .map { (error, retry) in recovery(for: error) ?? retry }
                .map(CocoaAction.init)

        recoveryButton.reactive.makeBindingTarget(on: UIScheduler(), { (button, title) in
            button.title = title
        }) <~ representedErrorProducer.map { $0.0 }.map(recoveryDescription)
    }
}

fileprivate func errorTitle(with activityDescription: String) -> String {
    return "An error occured while \(activityDescription)"
}

fileprivate func localizedDescription(for error: APIAccessError) -> String {
    switch error {
    case .noCredentials:
        return "No credentials configured. Please configure your Toggl credentials."
    case .authenticationError(response: _):
        return "Authentication error. Check your Toggl credentials."
    case .loadingSubsystemError(underlyingError: let underlyingError):
        return "The request failed with the following error:\n\(underlyingError.localizedDescription)"
    case .serverHiccups(response: let response, data: _):
        return "It seems like the Toggl server is experiencing internal difficulties. Response code is \(response.statusCode)."
    case .invalidJSON(underlyingError: _, data: _):
        return "Got some unexpectedly formed JSON as part of the response."
    case .nonHTTPResponseReceived(response: let response):
        return "Received what seems not to be an HTTP response: \(response.description)"
    case .otherHTTPError(response: let response):
        return "Received an HTTP error that I don't know how to handle. Response code is \(response.statusCode)."
    }
}

fileprivate func recovery(for error: APIAccessError) -> RecoveryAction? {
    switch error {
    case .noCredentials, .authenticationError:
        return RecoveryAction {
            NotificationCenter.default.post(name: ConfigureUserAccountRequestedNotificationName, object: nil)
            return SignalProducer<Void, NoError>.empty
        }
    default: return nil
    }
}

fileprivate func recoveryDescription(for error: APIAccessError) -> String {
    switch error {
    case .noCredentials, .authenticationError:
        return "Open Preferences"
    default:
        return "Retry"
    }
}
