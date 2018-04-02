//
//  SingleActivityViewController.swift
//  LayoutTests
//
//  Created by David Davila on 31.03.18.
//  Copyright © 2018 David Dávila. All rights reserved.
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

    fileprivate lazy var representedActivity = representedActivityStatus.map { $0?.activity }
}

fileprivate extension ActivityStatus.Activity {
    var descriptionForUI: String {
        switch self {
        case .syncProfile: return "profile"
        case .syncProjects: return "projects"
        case .syncReports: return "reports"
        case .syncRunningEntry: return "running entry"
        }
    }
}

class SyncingActivityViewController: SingleActivityViewController {

    @IBOutlet weak var progressIndicator: NSProgressIndicator!


    override func viewDidLoad() {
        super.viewDidLoad()
        progressIndicator.startAnimation(nil)
        label.reactive.text <~ representedActivity.producer.skipNil().map { "Syncing \($0.descriptionForUI)" }
    }
}

class ActivitySuccessViewController: SingleActivityViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        label.reactive.text <~ representedActivity.producer.skipNil().map { "Synced \($0.descriptionForUI)" }
    }
}

class ActivityErrorViewController: SingleActivityViewController {

    private var errorDetailsPopover: NSPopover?

    @IBAction func toggleErrorDetails(_ sender: NSButton) {
        switch sender.state {
        case .on: showErrorDetailsPopover(relativeTo: sender)
        case .off: closeDetailsPopover()
        default: break
        }
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
                                for: "syncing \(errorActivityStatus.activity.descriptionForUI)",
                                retryAction: retryAction)
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxX)
        self.errorDetailsPopover = popover
    }

    private func closeDetailsPopover() {
        guard let popover = errorDetailsPopover else {
            return
        }
        popover.close()
        errorDetailsPopover = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        label.reactive.text <~ representedActivity.producer.skipNil().map { "Error syncing \($0.descriptionForUI)" }
    }
}

