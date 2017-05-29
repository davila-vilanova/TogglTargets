//
//  SelectionDetailViewController.swift
//  TogglGoals
//
//  Created by David Davila on 03.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

class SelectionDetailViewController: NSTabViewController, ModelCoordinatorContaining {
    private enum TabViewItemIndex: Int {
        case emptySelection
        case projectDetails
    }

    internal var modelCoordinator: ModelCoordinator? {
        didSet {
            setupModelCoordinatorInChildControllers()
        }
    }

    internal var selection: Project? {
        didSet {
            if let project = selection {
                let projectDetailsController = display(.projectDetails) as! ProjectDetailsViewController
                projectDetailsController.representedProject = project
            } else {
                display(.emptySelection)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModelCoordinatorInChildControllers()
    }

    @discardableResult
    private func display(_ index: TabViewItemIndex) -> NSViewController {
        selectedTabViewItemIndex = index.rawValue
        return tabViewItems[selectedTabViewItemIndex].viewController!
    }

    private func setupModelCoordinatorInChildControllers() {
        for item in tabViewItems {
            if var modelCoordinatorContainer = item.viewController as? ModelCoordinatorContaining {
                modelCoordinatorContainer.modelCoordinator = self.modelCoordinator
            }
        }
    }
}
