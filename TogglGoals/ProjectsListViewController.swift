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
                bindToProjects()
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

        bindToProjects()
    }

    private var observedProjects: ObservedProperty<[Project]>?

    private func bindToProjects() {
        guard observedProjects == nil else {
            return
        }

        if let projectsProperty = modelCoordinator?.projects {
            observedProjects =
                ObservedProperty<[Project]>(original: projectsProperty,
                                            valueObserver: { [weak self] (projects) in
                                                if let p = projects {
                                                    self?.projects = p
                                                }
                                            },
                                            invalidationObserver: { [weak self] in
                                                self?.observedProjects = nil
                                            })
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
