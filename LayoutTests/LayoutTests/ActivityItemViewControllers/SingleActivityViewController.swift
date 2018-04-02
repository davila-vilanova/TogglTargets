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

@testable import TogglGoals_MacOS

class SingleActivityViewController: NSViewController {
    @IBOutlet weak var label: NSTextField!

    override var representedObject: Any? {
        get {
            return representedActivity.value
        }
        set(value) {
            representedActivity.value = (value as? ActivityStatus)?.activity
        }
    }

    fileprivate let representedActivity = MutableProperty<ActivityStatus.Activity?>(nil)
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
    override func viewDidLoad() {
        super.viewDidLoad()
        label.reactive.text <~ representedActivity.producer.skipNil().map { "Error syncing \($0.descriptionForUI)" }
    }
}

