//
//  LoggedInViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 01.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

class LoggedInViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        existingCredential: SignalProducer<TogglAPITokenCredential?, NoError>,
        testURLSessionAction: RetrieveProfileNetworkAction,
        logOut: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Outlets and action


    @IBOutlet weak var loggedInAsLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var retryButton: NSButton!
    @IBOutlet weak var fullNameField: NSTextField!
    @IBOutlet weak var profileImageView: NSImageView!
    @IBOutlet weak var profileImageWrapper: NSView!
    @IBOutlet weak var logOutButton: NSButton!


    // MARK: - Wiring

    override func viewDidLoad() {
        setupProfileImageStyle()

        let validBindings = lastBinding.producer.skipNil()
        let currentAction = Property(initial: nil, then: validBindings.map { $0.testURLSessionAction }).producer.skipNil()
        let currentCredential = Property(initial: nil, then: validBindings.map { $0.existingCredential }.flatten(.latest))
        let currentActionPlusCredential = Property<(RetrieveProfileNetworkAction, TogglAPITokenCredential?)?>(initial: nil, then: SignalProducer.combineLatest(currentAction, currentCredential.producer))

        reactive.lifetime += currentActionPlusCredential.producer.skipNil()
            .on(value: { $0.0.apply(URLSession(togglAPICredential: $0.1)).start() }).start()

        let retryActions = currentActionPlusCredential.producer.skipNil().map { (underlyingAction, credential) -> RetryAction in
            return RetryAction(enabledIf: underlyingAction.isEnabled) {
                underlyingAction.apply(URLSession(togglAPICredential: credential)).start()
                return SignalProducer.empty
            }
        }

        retryButton.reactive.makeBindingTarget { $0.reactive.pressed = $1 } <~ retryActions.map { CocoaAction($0) }

        let profiles = currentAction.map { $0.values }.flatten(.latest)
        let busyStates = currentAction.map { $0.isExecuting }.flatten(.latest)
        let errors = currentAction.map { $0.errors }.flatten(.latest)

        let showStatusLabel = SignalProducer.merge(busyStates,
                                                   profiles.map { _ in false },
                                                   errors.map { _ in true })

        statusLabel.reactive.makeBindingTarget { $0.isHidden = $1 } <~ showStatusLabel.negate()
        fullNameField.reactive.makeBindingTarget { $0.isHidden = $1 } <~ showStatusLabel
        loggedInAsLabel.reactive.makeBindingTarget { $0.isHidden = $1 } <~ showStatusLabel
        progressIndicator.reactive.makeBindingTarget { $1 ? $0.startAnimation(nil) : $0.stopAnimation(nil) } <~ busyStates
        retryButton.isHidden = true
        retryButton.reactive.makeBindingTarget { $0.isHidden = $1 } <~ SignalProducer.merge(profiles.map { _ in true },
                                                                                            errors.map { _ in false })

        statusLabel.reactive.stringValue <~
            SignalProducer.merge(profiles.map { _ in "" },
                                 busyStates.filter { $0 }
                                    .map { _ in
                                        NSLocalizedString("logged-in.loading-profile",
                                                          comment: "loading profile status description") },
                                 errors.map(localizedDescription))

        fullNameField.reactive.stringValue <~ SignalProducer.merge(profiles.map { $0.name }.skipNil(),
                                                                   errors.map { _ in "" })
        profileImageView.reactive.image <~ SignalProducer.merge(profiles.map { $0.imageUrl }.skipNil().map { NSImage(contentsOf: $0) }.skipNil(),
                                                                errors.map { _ in NSImage(named: NSImage.Name.user) }.skipNil())

        let logOutTitle = logOutButton.title
        logOutButton.reactive.makeBindingTarget { $0.title = $1 } <~
            SignalProducer.merge(
                errors.map {
                    switch $0 {
                    case .noCredentials, .authenticationError:
                        return NSLocalizedString("logged-in.reenter-credentials", comment: "reenter credentials button caption")
                    default: return logOutTitle
                    }
                },
                profiles.map { _ in logOutTitle })


        let requestLogOut = Action<Void, Void, NoError> { SignalProducer(value: ()) }
        logOutButton.reactive.pressed = CocoaAction(requestLogOut)

        requestLogOut.values.bindOnlyToLatest(validBindings.map { $0.logOut })
    }

    private func setupProfileImageStyle() {
        if let picLayer = profileImageView.layer {
            picLayer.borderColor = NSColor.darkGray.cgColor
            picLayer.borderWidth = 0.5
            picLayer.cornerRadius = 7.5
            picLayer.masksToBounds = true
        }
        if let shadowLayer = profileImageWrapper.layer {
            shadowLayer.shadowOpacity = 0.3
            shadowLayer.shadowOffset = CGSize(width: 0, height: -1)
            shadowLayer.masksToBounds = false
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        reactive.makeBindingTarget { $1.makeFirstResponder($0) } <~
            reactive.producer(forKeyPath: "view.window").skipNil().filterMap { $0 as? NSWindow }
                .delay(0, on: QueueScheduler())
                .take(first: 1)
    }
}
