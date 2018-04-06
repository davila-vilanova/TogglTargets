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

fileprivate let itemHeight: CGFloat = 30
fileprivate let kHeightConstraintIdentifier = "HeightConstraintIdentifier"
fileprivate let kAnimationDuration = 0.10

class LayoutTestsViewController: NSViewController {
    func connectInterface(showLabel: SignalProducer<Bool, NoError>) {
        self.showLabel <~ showLabel
    }

    private let showLabel = MutableProperty(true)

    private let (lifetime, token) = Lifetime.make()

    @IBOutlet weak var label: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        label.reactive.makeBindingTarget { $0.animator().isHidden = $1 } <~ showLabel
    }
}
