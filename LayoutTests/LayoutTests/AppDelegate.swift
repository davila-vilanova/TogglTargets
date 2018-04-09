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

let globalAnimationDuration: TimeInterval = 1.5

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let showLabel = MutableProperty(true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")

        let window = NSApplication.shared.windows.first!
        let splitVC = (window.contentViewController as! NSSplitViewController)
        let layoutTestVC = splitVC.splitViewItems[1].viewController as! LayoutTestsViewController
        layoutTestVC.view.layer!.backgroundColor = CGColor(gray: 0.7, alpha: 1)
        layoutTestVC.connectInterface(showLabel: showLabel.producer)
    }

    @IBAction func togglShowLabel(_ sender: Any) {
        showLabel.value = !showLabel.value
    }
}
