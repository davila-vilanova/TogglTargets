//
//  SelectionDetailViewController.swift
//  TogglGoals
//
//  Created by David Davila on 03.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift

fileprivate let ProjectDetailsVCContainment = "ProjectDetailsVCContainment"
fileprivate let EmtpySelectionVCContainment = "EmtpySelectionVCContainment"

class SelectionDetailViewController: NSViewController, ViewControllerContaining {
    
    // MARK: - Contained view controllers
    
    var projectDetailsViewController: ProjectDetailsViewController!
    var emptySelectionViewController: EmptySelectionViewController!
    
    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller {
        case _ where (controller as? ProjectDetailsViewController) != nil:
            projectDetailsViewController = controller as! ProjectDetailsViewController
        case _ where (controller as? EmptySelectionViewController) != nil:
            emptySelectionViewController = controller as! EmptySelectionViewController
        default: break
        }
    }

    private func setupConnectionsToContainedViewControllers() {
        guard isViewLoaded else {
            return
        }
        projectDetailsViewController.project <~ _project
    }

    private func setupContainedViewControllerVisibility() {
        _project.map { $0 != nil }.producer.observe(on: UIScheduler()).startWithValues { [projectDetailsViewController, emptySelectionViewController, view] projectAvailable in
            guard let projectDetailsViewController = projectDetailsViewController,
                let emptySelectionViewController = emptySelectionViewController else {
                    return
            }
            let containedVC = projectAvailable ? projectDetailsViewController : emptySelectionViewController
            displayController(containedVC, in: view)
        }
    }


    // MARK: - Data flow from parent view controller

    var project: BindingTarget<Project?> { return _project.bindingTarget }



    // MARK: - Data flow to contained view controllers

    private let _project = MutableProperty<Project?>(nil)


    // MARK: - ModelCoordinator

    var modelCoordinator: ModelCoordinator? {
        didSet {
            setupModelCoordinatorInContainedViewControllers()
        }
    }

    private func setupModelCoordinatorInContainedViewControllers() {
        guard isViewLoaded, let modelCoordinator = modelCoordinator else {
            return
        }
        projectDetailsViewController.modelCoordinator = modelCoordinator
    }


    // MARK : -

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [ProjectDetailsVCContainment, EmtpySelectionVCContainment])
        setupModelCoordinatorInContainedViewControllers()
        setupConnectionsToContainedViewControllers()
        setupContainedViewControllerVisibility()
    }
}
