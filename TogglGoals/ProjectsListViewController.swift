//
//  ProjectsListViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, ModelCoordinatorContaining {
    let projectItemIdentifier = "ProjectItemIdentifier"

    var modelCoordinator: ModelCoordinator? {
        didSet {
            if (isViewLoaded) {
                setupProjectsUpdating()
            }
        }
    }

    var projects: [Project]? {
        didSet {
            refresh()
        }
    }

    @IBOutlet weak var projectsCollectionView: NSCollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        projectsCollectionView.dataSource = self
        projectsCollectionView.maxNumberOfColumns = 1

        let collectionViewItemNib = NSNib(nibNamed: "ProjectCollectionViewItem", bundle: nil)!
        projectsCollectionView.register(collectionViewItemNib, forItemWithIdentifier: projectItemIdentifier)

        setupProjectsUpdating()
    }

    private var didSetupProjectsUpdating = false
    func setupProjectsUpdating() {
        guard !didSetupProjectsUpdating else {
            return
        }
        if let coordinator = modelCoordinator {
            self.projects = coordinator.projects
            NotificationCenter.default.addObserver(forName: ModelCoordinator.ProjectsUpdatedNotificationName, object: coordinator, queue: OperationQueue.main) { (notification) in
                self.projects = coordinator.projects
            }
            didSetupProjectsUpdating = true
        }
    }

    func refresh() {
        projectsCollectionView.reloadData()
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if let projects = self.projects {
            return projects.count
        } else {
            return 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: projectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem
        projectItem.projectName = projects![indexPath.item].name
        return projectItem
    }
}
