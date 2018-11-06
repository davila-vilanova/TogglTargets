//
//  ErrorViewController.swift
//  TogglTargets
//
//  Created by David Davila on 01.04.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

let configureUserAccountRequested =
    NSNotification.Name(rawValue: "ConfigureUserAccountRequestedNotification")

private typealias RecoveryAction = Action<Void, Void, NoError>

class ErrorViewController: NSViewController {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var recoveryButton: NSButton!

    func displayError(_ error: APIAccessError, title: String, retryAction: RetryAction) {
        representedError.value = (error, title, retryAction)
        print(error.debugDescription)
    }

    private let representedError = MutableProperty<(APIAccessError, String, RetryAction)?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        let representedErrorProducer = representedError.producer.skipNil()

        titleLabel.reactive.text <~ representedErrorProducer.map { $0.1 }
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

private func recovery(for error: APIAccessError) -> RecoveryAction? {
    switch error {
    case .noCredentials, .authenticationError:
        return RecoveryAction {
            NotificationCenter.default.post(name: configureUserAccountRequested, object: nil)
            return SignalProducer<Void, NoError>.empty
        }
    default: return nil
    }
}

private func recoveryDescription(for error: APIAccessError) -> String {
    switch error {
    case .noCredentials, .authenticationError:
        return NSLocalizedString("status.activity.error.recovery.open-preferences",
                                 comment: "error recovery description: open app preferences to configure credentials")
    default:
        return NSLocalizedString("status.activity.error.recovery.retry",
                                 comment: "error recovery description: retry operation")
    }
}
