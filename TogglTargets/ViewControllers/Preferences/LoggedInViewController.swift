//
//  LoggedInViewController.swift
//  TogglTargets
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
        profile: SignalProducer<Profile, NoError>,
        apiAccessError: SignalProducer<APIAccessError, NoError>,
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

    private lazy var retrieveProfilePictureImageData = Action<URL, (Data, URLResponse), AnyError> { imageURL in
        URLSession.shared.reactive.data(with: URLRequest(url: imageURL))
    }

    // MARK: - Wiring

    override func viewDidLoad() {
        setupProfileImageStyle()

        progressIndicator.reactive.makeBindingTarget { $1 ? $0.startAnimation(nil) : $0.stopAnimation(nil) } <~ retrieveProfilePictureImageData.isExecuting

        let profile = lastBinding.latestOutput { $0.profile }
        fullNameField.reactive.stringValue <~ profile.filterMap { $0.name } // TODO: or make name not optional, it probably is not on Toggl's side
        profileImageView.reactive.image <~ retrieveProfilePictureImageData.values.map { $0.0 }.map { NSImage(data: $0) }
        retrieveProfilePictureImageData <~ profile.filterMap { $0.imageUrl } // TODO: ditto?
        timezoneField.reactive.stringValue <~ profile.filterMap { $0.timezone } // once again
        workspaceCountField.reactive.stringValue <~ profile.map {
            String.localizedStringWithFormat(NSLocalizedString("preferences.logged-in.workspace-count",
                                                               comment: "count of workspaces managed by the Toggl account"), $0.workspaces.count)

        }

        showCredentialsErrorAlert <~ lastBinding.latestOutput { $0.apiAccessError }
            .map { _ in () }
            .throttle(while: Property(initial: true,
                                      then: reactive.producer(forKeyPath: "view.window").map { $0 == nil }),
                      on: UIScheduler())

        let requestLogOutButtonPress = Action<Void, Void, NoError> { SignalProducer(value: ()) }
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

    private lazy var showCredentialsErrorAlert = Action<Void, CredentialsErrorResolution, NoError> { [unowned self] in
        guard let window = self.view.window else {
            return SignalProducer.empty
        }

        return SignalProducer { (observer: Signal<CredentialsErrorResolution, NoError>.Observer, _: Lifetime) in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString("logged-in.invalid-credentials.title", comment: "credential seems no longer valid: title")
            alert.informativeText = NSLocalizedString("logged-in.invalid-credentials.informative", comment: "credential seems no longer valid: informative text")

            alert.addButton(withTitle: NSLocalizedString("logged-in.invalid-credentials.ignore", comment: "button caption: ignore invalid credentials error"))
            alert.addButton(withTitle: NSLocalizedString("logged-in.invalid-credentials.reenter", comment: "Reenter Credentials"))

            alert.beginSheetModal(for: window) { response in
                switch response {
                case .alertFirstButtonReturn: observer.send(value: .ignore)
                case .alertSecondButtonReturn: fallthrough
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
            reactive.producer(forKeyPath: "view.window").skipNil().filterMap { $0 as? NSWindow }
                .delay(0, on: QueueScheduler())
                .take(first: 1)
    }
}
