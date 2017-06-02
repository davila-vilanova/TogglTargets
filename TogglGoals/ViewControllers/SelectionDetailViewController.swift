//
//  SelectionDetailViewController.swift
//  TogglGoals
//
//  Created by David Davila on 03.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

fileprivate let ProjectDetailsVCContainment = "ProjectDetailsVCContainment"
fileprivate let EmtpySelectionVCContainment = "EmtpySelectionVCContainment"

class SelectionDetailViewController: NSViewController, ViewControllerContaining, ModelCoordinatorContaining {
    
    // MARK: - Child view controllers containment
    
    var projectDetailsViewController: ProjectDetailsViewController! {
        didSet {
            projectDetailsViewController.modelCoordinator = self.modelCoordinator
        }
    }
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
    
    
    // MARK : -
    
    internal var modelCoordinator: ModelCoordinator? {
        didSet {
            if let detailsController = projectDetailsViewController {
                detailsController.modelCoordinator = modelCoordinator
            }
        }
    }

    internal var selection: Project? {
        didSet {
            if let project = selection {
                projectDetailsViewController.representedProject = project
                displayController(projectDetailsViewController, in: view)
            } else {
                displayController(emptySelectionViewController, in: view)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeControllerContainment(containmentIdentifiers: [ProjectDetailsVCContainment, EmtpySelectionVCContainment])
    }
}
