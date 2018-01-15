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
        case .retrieveProfile: retrievingWhat = "profile"
        case .retrieveProjects: retrievingWhat = "projects"
        case .retrieveReports: retrievingWhat = "reports"
        case .retrieveRunningEntry: retrievingWhat = "running entry"
        case .retrieveAll: retrievingWhat = "data"
        }

        progressDescriptionTextField.stringValue = "Synchronizing \(retrievingWhat)"
    }
}
