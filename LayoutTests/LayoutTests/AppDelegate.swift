//
//  AppDelegate.swift
//  LayoutTests
//
//  Created by David Davila on 24.03.18.
//  Copyright © 2018 David Dávila. All rights reserved.
//

import Cocoa
import ReactiveSwift
@testable import TogglGoals_MacOS

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let showLabel = MutableProperty(true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")

        let window = NSApplication.shared.windows.first!
        let viewController = window.contentViewController as! LayoutTestsViewController
        viewController.connectInterface(showLabel: showLabel.producer)
    }

    @IBAction func togglShowLabel(_ sender: Any) {
        showLabel.value = !showLabel.value
    }
}
