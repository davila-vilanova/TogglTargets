//
//  LoggedInViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 01.05.18.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class LoggedInViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        profile: SignalProducer<Profile, Never>,
        apiAccessError: SignalProducer<APIAccessError, Never>,
        logOut: BindingTarget<Void>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Outlets and action

    @IBOutlet weak var loggedInAsLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var fullNameField: NSTextField!
    @IBOutlet weak var profileImageView: NSImageView!
    @IBOutlet weak var profileImageWrapper: NSView!
    @IBOutlet weak var workspaceCountField: NSTextField!
    @IBOutlet weak var timezoneField: NSTextField!
    @IBOutlet weak var logOutButton: NSButton!

    // MARK: -

    private lazy var retrieveProfilePictureImageData = Action<URL, (Data, URLResponse), Error> { imageURL in
        URLSession.shared.reactive.data(with: URLRequest(url: imageURL))
    }

    // MARK: - Wiring

    override func viewDidLoad() {
        setupProfileImageStyle()

        progressIndicator.reactive.makeBindingTarget {
            $1 ? $0.startAnimation(nil) : $0.stopAnimation(nil)
            } <~ retrieveProfilePictureImageData.isExecuting

        let profile = lastBinding.latestOutput { $0.profile }
        fullNameField.reactive.stringValue <~ profile.compactMap { $0.name }
        profileImageView.reactive.image <~ retrieveProfilePictureImageData.values.map { $0.0 }.map { NSImage(data: $0) }
        retrieveProfilePictureImageData <~ profile.compactMap { $0.imageUrl }
        timezoneField.reactive.stringValue <~ profile.compactMap { $0.timezone }
        workspaceCountField.reactive.stringValue <~ profile.map {
            String.localizedStringWithFormat(
                NSLocalizedString("preferences.logged-in.workspace-count",
                                  comment: "count of workspaces managed by the Toggl account"), $0.workspaces.count)
        }

        showCredentialsErrorAlert <~ lastBinding.latestOutput { $0.apiAccessError }
            .map { _ in () }
            .throttle(while: Property(initial: true,
                                      then: reactive.producer(forKeyPath: "view.window").map { $0 == nil }),
                      on: UIScheduler())

        let requestLogOutButtonPress = Action<Void, Void, Never> { SignalProducer(value: ()) }
        logOutButton.reactive.pressed = CocoaAction(requestLogOutButtonPress)

        let requestLogOut = Signal.merge(requestLogOutButtonPress.values,
                                         showCredentialsErrorAlert.values.filter { $0.isReenter }
                                            .map { _ in () })

        requestLogOut.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.logOut })
    }

    private enum CredentialsErrorResolution {
        case reenter
        case ignore

        var isReenter: Bool {
            switch self {
            case .reenter: return true
            default: return false
            }
        }
    }

    private lazy var showCredentialsErrorAlert = Action<Void, CredentialsErrorResolution, Never> { [unowned self] in
        guard let window = self.view.window else {
            return SignalProducer.empty
        }

        return SignalProducer { (observer: Signal<CredentialsErrorResolution, Never>.Observer, _: Lifetime) in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString("logged-in.invalid-credentials.title",
                                                  comment: "credential seems no longer valid: title")
            alert.informativeText = NSLocalizedString("logged-in.invalid-credentials.informative",
                                                      comment: "credential seems no longer valid: informative text")

            alert.addButton(withTitle: NSLocalizedString("logged-in.invalid-credentials.ignore",
                                                         comment: "button caption: ignore invalid credentials error"))
            alert.addButton(withTitle: NSLocalizedString("logged-in.invalid-credentials.reenter",
                                                         comment: "reenter credentials"))

            alert.beginSheetModal(for: window) { response in
                switch response {
                case .alertFirstButtonReturn: observer.send(value: .ignore)
                default: observer.send(value: .reenter)
                }
                observer.sendCompleted()
            }
        }
    }

    private func setupProfileImageStyle() {
        if let picLayer = profileImageView.layer {
            picLayer.borderColor = NSColor.darkGray.cgColor
            picLayer.borderWidth = 0.5
            picLayer.cornerRadius = 7.5
            picLayer.masksToBounds = true
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        reactive.makeBindingTarget { $1.makeFirstResponder($0) } <~
        reactive.producer(forKeyPath: "view.window").skipNil().compactMap { $0 as? NSWindow }
                .delay(0, on: QueueScheduler())
                .take(first: 1)
    }
}
