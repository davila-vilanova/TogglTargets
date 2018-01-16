//
//  ActivityCollectionViewProgressItem.swift
//  TogglGoals
//
//  Created by David Dávila on 02.01.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

class ActivityCollectionViewProgressItem: NSCollectionViewItem, ActivityDisplaying {

    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var progressDescriptionTextField: NSTextField!

    func setDisplayActivity(_ activity: ActivityStatus.Activity) {
        progressIndicator.startAnimation(nil)
        
        let retrievingWhat: String

        switch activity {
        case .syncProfile: retrievingWhat = "profile"
        case .syncProjects: retrievingWhat = "projects"
        case .syncReports: retrievingWhat = "reports"
        case .syncRunningEntry: retrievingWhat = "running entry"
        case .all: retrievingWhat = "data"
        }

        progressDescriptionTextField.stringValue = "Synchronizing \(retrievingWhat)"
    }
}
