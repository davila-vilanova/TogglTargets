//
//  ViewController.swift
//  LayoutTests
//
//  Created by David Davila on 24.03.18.
//  Copyright © 2018 David Dávila. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS

class LayoutTestsViewController: NSViewController {
    func connectInterface(showLabel: SignalProducer<Bool, NoError>) {
        self.showLabel <~ showLabel
    }

    private let showLabel = MutableProperty(true)

    private let (lifetime, token) = Lifetime.make()

    @IBOutlet weak var label: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        label.reactive.makeBindingTarget { view, value in
            NSAnimationContext.runAnimationGroup({ context in
//                context.duration = 0.5
                context.allowsImplicitAnimation = true
                view.isHidden = value
                view.superview!.layoutSubtreeIfNeeded()
            }, completionHandler: nil)
            } <~ showLabel
    }
}
