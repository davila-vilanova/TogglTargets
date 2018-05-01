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
        testURLSessionAction: TestURLSessionAction,
        logOut: BindingTarget<Void>)
    // incoming credential must have been valid at some point, otherwise it wouldn't have made it past the Account VC

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Outlets and action

    @IBOutlet weak var fullNameField: NSTextField!
    @IBOutlet weak var profileImageView: NSImageView!

    @IBAction func logOut(_ sender: Any) {
        requestLogOut <~ SignalProducer(value: ())
    }


    // MARK: - Wiring

    private let requestLogOut = MutableProperty<Void>(())

    override func viewDidLoad() {
        let validBindings = lastBinding.producer.skipNil()
        let credentialsProducerProducer = validBindings.map { $0.existingCredential }
        let retrieveProfileActionProducer = lastBinding.producer.skipNil().map { $0.testURLSessionAction }
            .combineLatest(with: credentialsProducerProducer)
            .map { (retrieveProfileAction: TestURLSessionAction, credentialsProducer: SignalProducer<TogglAPITokenCredential?, NoError>) -> TestURLSessionAction in
                let urlSessions: SignalProducer<URLSession?, NoError> = credentialsProducer.map(URLSession.init)
                retrieveProfileAction <~ urlSessions
                return retrieveProfileAction
        }

        let profileProducer: SignalProducer<Profile, NoError> = retrieveProfileActionProducer.map { $0.values }.producer.flatten(.latest)

        fullNameField.reactive.stringValue <~ profileProducer.map { $0.name }.skipNil()
        profileImageView.reactive.image <~ profileProducer.map { $0.imageUrl }.skipNil().map { NSImage(contentsOf: $0) }.skipNil()

        requestLogOut.bindOnlyToLatest(validBindings.map { $0.logOut })
    }
}
