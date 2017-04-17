//
//  ProjectsListViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, ModelCoordinatorContaining {
    let projectItemIdentifier = "ProjectItemIdentifier"

    internal var didSelectProject: ( (Project?) -> () )?

    var modelCoordinator: ModelCoordinator? {
        didSet {
            if (isViewLoaded) {
                bindToProjects()
            }
        }
    }

    var projectIds: [Int64]? {
        didSet {
            refresh()
        }
    }

    @IBOutlet weak var projectsCollectionView: NSCollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        projectsCollectionView.dataSource = self
        projectsCollectionView.delegate = self
        projectsCollectionView.maxNumberOfColumns = 1

        let collectionViewItemNib = NSNib(nibNamed: "ProjectCollectionViewItem", bundle: nil)!
        projectsCollectionView.register(collectionViewItemNib, forItemWithIdentifier: projectItemIdentifier)

        bindToProjects()
    }

    private var observedProjectIds: ObservedProperty<[Int64]>?

    private func bindToProjects() {
        guard observedProjectIds == nil else {
            return
        }

        if let projectIdsProperty = modelCoordinator?.sortedProjectIdsProperty {
            observedProjectIds =
                ObservedProperty<[Int64]>(original: projectIdsProperty,
                                            valueObserver: { [weak self] (projectIds) in
                                                if let p = projectIds {
                                                    self?.projectIds = p
                                                }
                                            },
                                            invalidationObserver: { [weak self] in
                                                self?.observedProjectIds = nil
                                            })
        }
    }

    func refresh() {
        projectsCollectionView.reloadData()
        updateSelection()
    }

    private func updateSelection() {
        if let index = projectsCollectionView.selectionIndexPaths.first?.item,
            let projectId = projectIds?[index],
            let project = modelCoordinator?.project(for: projectId) {
            didSelectProject?(project)
        } else {
            didSelectProject?(nil)
        }
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if let projectsIds = self.projectIds {
            return projectsIds.count
        } else {
            return 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: projectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem
        
        if let projectId = projectIds?[indexPath.item],
            let project = modelCoordinator?.project(for: projectId) {
            projectItem.projectName = project.name
            projectItem.goalProperty = modelCoordinator?.goalProperty(for: projectId)
            projectItem.reportProperty = modelCoordinator?.reportProperty(for: projectId)
        }
        
        return projectItem
    }

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }
}
