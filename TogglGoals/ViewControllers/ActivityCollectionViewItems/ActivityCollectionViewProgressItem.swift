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

    func setDisplayActivity(_ activity: RetrievalActivity) {
        progressIndicator.startAnimation(nil)
        
        let retrievingWhat: String

        switch activity {
        case .profile: retrievingWhat = "profile"
        case .projects: retrievingWhat = "projects"
        case .reports: retrievingWhat = "reports"
        case .runningEntry: retrievingWhat = "running entry"
        }

        progressDescriptionTextField.stringValue = "Retrieving \(retrievingWhat)"
    }
}
