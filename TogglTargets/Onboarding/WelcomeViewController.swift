//
//  WelcomeViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 14.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class WelcomeViewController: NSViewController {

    @IBOutlet weak var continueButton: NSButton!

    private let continueAction = Action<Void, Void, NoError> {
        SignalProducer(value: ())
    }

    var continuePressed: Signal<Void, NoError> {
        return continueAction.values
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        continueButton.reactive.pressed = CocoaAction(continueAction)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window!.initialFirstResponder = continueButton
    }

    @IBAction func openTogglDotCom(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://toggl.com")!)
    }
}
