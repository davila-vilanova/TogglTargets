//
//  ErrorViewController.swift
//  TogglGoals
//
//  Created by David Davila on 01.04.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class ErrorViewController: NSViewController {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var retryButton: NSButton!

    func displayError(_ error: APIAccessError, for activityDescription: String, retryAction: RetryAction) {
        representedError.value = (error, activityDescription, retryAction)
    }

    private let representedError = MutableProperty<(APIAccessError, String, RetryAction)?>(nil)
    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        let representedErrorProducer = representedError.producer.skipNil()

        titleLabel.reactive.text <~ representedErrorProducer.map { $0.1 }.map(errorTitle)
        descriptionLabel.reactive.text <~ representedErrorProducer.map { $0.0 }.map(errorDescriptionForUser)

        lifetime += representedErrorProducer.map { $0.2 }.startWithValues { [unowned self] in
            self.retryButton.reactive.pressed = CocoaAction($0)
        }
    }
}

fileprivate func errorTitle(with activityDescription: String) -> String {
    return "An error occured while \(activityDescription)"
}

fileprivate func errorDescriptionForUser(from error: APIAccessError) -> String {
    switch error {
    case .noCredentials:
        return "No credentials configured. Click retry to enter your Toggl credentials."
    case .authenticationError(response: _):
        return "Authentication error. Click retry to re-enter your Toggl credentials."
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
