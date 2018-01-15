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
        case .retrieveProfile: retrievedWhat = "Profile"
        case .retrieveProjects: retrievedWhat = "Projects"
        case .retrieveReports: retrievedWhat = "Reports"
        case .retrieveRunningEntry: retrievedWhat = "Running entry"
        case .retrieveAll: retrievedWhat = "All data"
        }

        successDescriptionTextField.stringValue = "\(retrievedWhat) synchronized"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        successDescriptionTextField.stringValue = "ActivityCollectionViewSuccessItem"

    }
}
