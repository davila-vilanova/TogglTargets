//
//  ProjectsMasterDetailController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectsMasterDetailController: NSSplitViewController, ModelCoordinatorContaining {
    private var cachedModelCoordinator: ModelCoordinator?
    var modelCoordinator: ModelCoordinator? {
        get {
            // As the topmost controller, it will retrieve the ModelCoordinator from the app delegate and propagate it to the contained controllers

            if let coordinator = cachedModelCoordinator {
                return coordinator
            }
            let coordinator = (NSApplication.shared().delegate as! ModelCoordinatorContaining).modelCoordinator
            cachedModelCoordinator = coordinator
            return coordinator
        }

        set {
            cachedModelCoordinator = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModelCoordinatorInChildControllers()
    }

    private func setupModelCoordinatorInChildControllers() {
        for item in splitViewItems {
            if var modelCoordinatorContainer = item.viewController as? ModelCoordinatorContaining {
                modelCoordinatorContainer.modelCoordinator = self.modelCoordinator
            }
        }

    }
}
