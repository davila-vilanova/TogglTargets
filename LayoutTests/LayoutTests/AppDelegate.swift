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

    private var viewController: LayoutTestsViewController!

    private let activityStatuses = MutableProperty([ActivityStatus]())

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")

        let window = NSApplication.shared.windows.first!
        viewController = window.contentViewController as! LayoutTestsViewController
        viewController.connectInterface(activityStatuses: activityStatuses.producer)
    }

    @IBAction func addSyncingProfileActivity(_ sender: Any) {
        addActivity(.syncProfile)
    }

    @IBAction func addSyncingProjectsActivity(_ sender: Any) {
        addActivity(.syncProjects)
    }

    @IBAction func addSyncingReportsActivity(_ sender: Any) {
        addActivity(.syncReports)
    }

    @IBAction func addSyncingRunningEntryActivity(_ sender: Any) {
        addActivity(.syncRunningEntry)
    }

    @IBAction func removeSyncingProfileActivity(_ sender: Any) {
        removeActivity(.syncProfile)
    }

    @IBAction func removeSyncingProjectsActivity(_ sender: Any) {
        removeActivity(.syncProjects)
    }

    @IBAction func removeSyncingReportsActivity(_ sender: Any) {
        removeActivity(.syncReports)
    }

    @IBAction func removeSyncingRunningEntryActivity(_ sender: Any) {
        removeActivity(.syncRunningEntry)
    }

    private func addActivity(_ activity: ActivityStatus.Activity) {
        activityStatuses.value.append(.executing(activity))
    }

    private func removeActivity(_ activity: ActivityStatus.Activity) {
        activityStatuses.value.remove(at: activityStatuses.value.index { $0.activity == activity }! )
    }
}

