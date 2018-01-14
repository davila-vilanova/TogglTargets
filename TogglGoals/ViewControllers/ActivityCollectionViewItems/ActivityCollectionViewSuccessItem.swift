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
        case .retrieveProfile: retrievedWhat = "profile"
        case .retrieveProjects: retrievedWhat = "projects"
        case .retrieveReports: retrievedWhat = "reports"
        case .retrieveRunningEntry: retrievedWhat = "running entry"
        }

        successDescriptionTextField.stringValue = "Successfully retrieved \(retrievedWhat)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        successDescriptionTextField.stringValue = "ActivityCollectionViewSuccessItem"

    }
}
