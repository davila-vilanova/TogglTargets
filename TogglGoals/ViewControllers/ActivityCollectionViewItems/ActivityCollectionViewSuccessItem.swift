//
//  ActivityCollectionViewSuccessItem.swift
//  TogglGoals
//
//  Created by David Dávila on 02.01.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

class ActivityCollectionViewSuccessItem: NSCollectionViewItem, ActivityDisplaying {

    @IBOutlet weak var successDescriptionTextField: NSTextField!

    func setDisplayActivity(_ activity: ActivityStatus.Activity) {
        let retrievedWhat: String

        switch activity {
        case .syncProfile: retrievedWhat = "Profile"
        case .syncProjects: retrievedWhat = "Projects"
        case .syncReports: retrievedWhat = "Reports"
        case .syncRunningEntry: retrievedWhat = "Running entry"
        case .all: retrievedWhat = "All data"
        }

        successDescriptionTextField.stringValue = "\(retrievedWhat) synchronized"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        successDescriptionTextField.stringValue = "ActivityCollectionViewSuccessItem"

    }
}
