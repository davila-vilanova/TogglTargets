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

    private var selectedProjectObservationDisposable: Disposable?
    internal var selectedProject: MutableProperty<Project?>? {
        didSet {
            // Propagate
            projectDetailsViewController.selectedProject = selectedProject

            // Process
            if let disposable = selectedProjectObservationDisposable {
                disposable.dispose()
            }
            guard let project = selectedProject else {
                selectedProjectObservationDisposable = nil
                return
            }
            selectedProjectObservationDisposable = project.producer.observe(on: UIScheduler()).startWithValues({ [weak self] (project) in
                guard let s = self else {
                    return
                }
                let viewController = (project == nil) ? s.emptySelectionViewController : s.projectDetailsViewController
                displayController(viewController, in: s.view)
            })
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeControllerContainment(containmentIdentifiers: [ProjectDetailsVCContainment, EmtpySelectionVCContainment])
    }
}
