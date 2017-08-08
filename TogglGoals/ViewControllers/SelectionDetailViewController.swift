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

    internal func setSelectedProject(_ project: MutableProperty<Project?>) {
        selectedProject <~ project
    }
    private var selectedProject = MutableProperty<Project?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeControllerContainment(containmentIdentifiers: [ProjectDetailsVCContainment, EmtpySelectionVCContainment])

        projectDetailsViewController.setSelectedProject(selectedProject)

        selectedProject.producer.observe(on: UIScheduler()).startWithValues { [weak self] projectOrNil in
            guard let s = self else {
                return
            }
            let viewController = (projectOrNil == nil) ? s.emptySelectionViewController : s.projectDetailsViewController
            displayController(viewController, in: s.view)
        }
    }
}
