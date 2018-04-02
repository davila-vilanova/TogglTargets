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

    @IBAction func triggerSyncingProfileSuccess(_ sender: Any) {
        triggerActivitySuccess(.syncProfile)
    }

    @IBAction func triggerSyncingProjectsSuccess(_ sender: Any) {
        triggerActivitySuccess(.syncProjects)
    }

    @IBAction func triggerSyncingReportsSuccess(_ sender: Any) {
        triggerActivitySuccess(.syncReports)
    }

    @IBAction func triggerSyncingRunningEntrySuccess(_ sender: Any) {
        triggerActivitySuccess(.syncRunningEntry)
    }

    @IBAction func triggerSyncingProfileError(_ sender: Any) {
        triggerActivityError(.syncProfile)
    }

    @IBAction func triggerSyncingProjectsError(_ sender: Any) {
        triggerActivityError(.syncProjects)
    }

    @IBAction func triggerSyncingReportsError(_ sender: Any) {
        triggerActivityError(.syncReports)
    }

    @IBAction func triggerSyncingRunningEntryError(_ sender: Any) {
        triggerActivityError(.syncRunningEntry)
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

    private func triggerActivitySuccess(_ activity: ActivityStatus.Activity) {
        guard let index = activityStatuses.value.index(where: { $0.activity == activity }) else {
            return
        }
        activityStatuses.value[index] = ActivityStatus.succeeded(activity)
    }

    private func triggerActivityError(_ activity: ActivityStatus.Activity) {
        guard let index = activityStatuses.value.index(where: { $0.activity == activity }) else {
            return
        }
        let retryAction = RetryAction { _ in
            print("retry \(activity)")
            return SignalProducer.empty
        }
        activityStatuses.value[index] = ActivityStatus.error(activity, APIAccessError.noCredentials, retryAction)
    }
}
