//
//  SingleActivityViewController.swift
//  LayoutTests
//
//  Created by David Davila on 31.03.18.
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

class SingleActivityViewController: NSViewController {
    @IBOutlet weak var label: NSTextField!

    override var representedObject: Any? {
        get {
            return representedActivityStatus.value
        }
        set(value) {
            representedActivityStatus.value = value as? ActivityStatus
        }
    }

    fileprivate let representedActivityStatus = MutableProperty<ActivityStatus?>(nil)
}

fileprivate extension ActivityStatus {
    var localizedDescription: String {
        switch self {
        case .executing(let activity):
            switch activity {
            case .syncProfile:
                return NSLocalizedString("status.activity.syncing.profile", comment: "syncing profile")
            case .syncProjects:
                return NSLocalizedString("status.activity.syncing.projects", comment: "syncing projects")
            case .syncReports:
                return NSLocalizedString("status.activity.syncing.projects", comment: "syncing reports")
            case .syncRunningEntry:
                return NSLocalizedString("status.activity.syncing.running-entry", comment: "syncing running entry")
            }
        case .succeeded(let activity):
            switch activity {
            case .syncProfile:
                return NSLocalizedString("status.activity.synced.profile", comment: "synced profile")
            case .syncProjects:
                return NSLocalizedString("status.activity.synced.projects", comment: "synced projects")
            case .syncReports:
                return NSLocalizedString("status.activity.synced.reports", comment: "synced reports")
            case .syncRunningEntry:
                return NSLocalizedString("status.activity.synced.running-entry", comment: "synced running entry")
            }
        case .error(let activity, _, _):
            switch activity {
            case .syncProfile:
                return NSLocalizedString("status.activity.error.profile", comment: "error syncing profile")
            case .syncProjects:
                return NSLocalizedString("status.activity.error.projects", comment: "error syncing projects")
            case .syncReports:
                return NSLocalizedString("status.activity.error.reports", comment: "error syncing reports")
            case .syncRunningEntry:
                return NSLocalizedString("status.activity.error.running-entry", comment: "error syncing running entry")
            }
        }
    }

    static func localizedDescription(for status: ActivityStatus) -> String {
        return status.localizedDescription
    }
}

class SyncingActivityViewController: SingleActivityViewController {

    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    override func viewDidLoad() {
        super.viewDidLoad()
        progressIndicator.startAnimation(nil)
        label.reactive.text <~ representedActivityStatus.producer.skipNil().map(ActivityStatus.localizedDescription)
    }
}

class ActivitySuccessViewController: SingleActivityViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        label.reactive.text <~ representedActivityStatus.producer.skipNil().map(ActivityStatus.localizedDescription)
    }
}

class ActivityErrorViewController: SingleActivityViewController, NSPopoverDelegate {

    private weak var errorDetailsPopover: NSPopover?

    @IBAction func showErrorDetails(_ sender: Any) {
        guard errorDetailsPopover?.isShown != true else {
            return
        }
        showErrorDetailsPopover(relativeTo: view)
    }

    private func showErrorDetailsPopover(relativeTo view: NSView) {
        guard let errorActivityStatus = representedActivityStatus.value,
            errorActivityStatus.isError,
            let error = errorActivityStatus.error,
            let retryAction = errorActivityStatus.retryAction,
            errorDetailsPopover == nil else {
            return
        }
        let controller = ErrorViewController()
        controller.displayError(error,
                                title: errorActivityStatus.localizedDescription,
                                retryAction: retryAction)
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxX)
        self.errorDetailsPopover = popover
    }

    func popoverDidClose(_ notification: Notification) {
        self.errorDetailsPopover = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let statuses = representedActivityStatus.producer.skipNil()

        // Single out no credentials errors
        let noCredentialsErrorDescriptions = statuses.filter(isNoCredentialsError).map { _ in
            NSLocalizedString("status.activity.error.no-credentials",
                              comment: "error: no credentials configured (in single activity view)")
        }

        label.reactive.text <~ SignalProducer.merge(noCredentialsErrorDescriptions,
                                                    statuses.filter(isOtherError)
                                                        .map(ActivityStatus.localizedDescription))
    }
}

private func isNoCredentialsError(_ status: ActivityStatus) -> Bool {
    switch status.error {
    case .some(.noCredentials): return true
    default: return false
    }
}

private func isOtherError(_ status: ActivityStatus) -> Bool {
    return !isNoCredentialsError(status)
}
