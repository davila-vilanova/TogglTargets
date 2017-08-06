//
//  ProjectsMasterDetailController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectsMasterDetailController: NSSplitViewController, ModelCoordinatorContaining {
    private enum SplitItemIndex: Int {
        case projectsList = 0
        case selectionDetail
    }

    private var _modelCoordinator: ModelCoordinator?
    internal var modelCoordinator: ModelCoordinator? {
        get {
            // As the topmost controller, it will retrieve the ModelCoordinator from the app delegate
            // and propagate it to the contained controllers

            if let coordinator = _modelCoordinator {
                return coordinator
            }
            let coordinator = (NSApplication.shared.delegate as! ModelCoordinatorContaining).modelCoordinator
            _modelCoordinator = coordinator
            return coordinator
        }

        set {
            _modelCoordinator = newValue
        }
    }

    private var projectsListViewController: ProjectsListViewController {
        return splitViewItem(.projectsList).viewController as! ProjectsListViewController
    }

    private var selectionDetailViewController: SelectionDetailViewController {
        return splitViewItem(.selectionDetail).viewController as! SelectionDetailViewController
    }

    private func splitViewItem(_ index: SplitItemIndex) -> NSSplitViewItem {
        return splitViewItems[index.rawValue]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModelCoordinatorInChildControllers()
        setupSelectedProjectProperty()
    }

    private func setupModelCoordinatorInChildControllers() {
        for item in splitViewItems {
            if var modelCoordinatorContainer = item.viewController as? ModelCoordinatorContaining {
                modelCoordinatorContainer.modelCoordinator = self.modelCoordinator
            }
        }
    }

    private func setupSelectedProjectProperty() {
        selectionDetailViewController.selectedProject = projectsListViewController.selectedProject
    }
}
