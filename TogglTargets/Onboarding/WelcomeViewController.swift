//
//  WelcomeViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 14.10.18.
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

class WelcomeViewController: NSViewController {

    @IBOutlet weak var continueButton: NSButton!

    private let continueAction = Action<Void, Void, Never> {
        SignalProducer(value: ())
    }

    var continuePressed: Signal<Void, Never> {
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
