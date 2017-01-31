//
//  ProjectDetailsViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectDetailsViewController: NSViewController, ModelCoordinatorContaining {

    var modelCoordinator: ModelCoordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    internal func onProjectSelected(projectId: Int64) {
        Swift.print("selected project with id=\(projectId)")
    }
}
