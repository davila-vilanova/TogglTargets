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

    func setDisplayActivity(_ activity: RetrievalActivity) {
        let retrievedWhat: String

        switch activity {
        case .profile: retrievedWhat = "profile"
        case .projects: retrievedWhat = "projects"
        case .reports: retrievedWhat = "reports"
        case .runningEntry: retrievedWhat = "running entry"
        }

        successDescriptionTextField.stringValue = "Successfully retrieved \(retrievedWhat)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        successDescriptionTextField.stringValue = "ActivityCollectionViewSuccessItem"

    }
}
