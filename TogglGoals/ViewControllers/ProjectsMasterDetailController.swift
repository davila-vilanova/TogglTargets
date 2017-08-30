//
//  ProjectsMasterDetailController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift

class ProjectsMasterDetailController: NSSplitViewController {
    private enum SplitItemIndex: Int {
        case projectsList = 0
        case selectionDetail
    }


    // MARK: - Contained view controllers

    private var projectsListViewController: ProjectsListViewController {
        return splitViewItem(.projectsList).viewController as! ProjectsListViewController
    }

    private var selectionDetailViewController: SelectionDetailViewController {
        return splitViewItem(.selectionDetail).viewController as! SelectionDetailViewController
    }

    private func splitViewItem(_ index: SplitItemIndex) -> NSSplitViewItem {
        return splitViewItems[index.rawValue]
    }

    private func setupConnectionsBetweenContainedViewControllers() {
        selectionDetailViewController.project <~ projectsListViewController.selectedProject
    }


    // MARK: - ModelCoordinator

    private func setupModelCoordinatorInContainedControllers() {
        guard isViewLoaded, let modelCoordinator = modelCoordinator else {
            return
        }
        projectsListViewController.modelCoordinator = modelCoordinator
        selectionDetailViewController.modelCoordinator = modelCoordinator
    }

    internal var modelCoordinator: ModelCoordinator? {
        didSet {
            setupModelCoordinatorInContainedControllers()
        }
    }


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModelCoordinatorInContainedControllers()
        setupConnectionsBetweenContainedViewControllers()
    }
}

