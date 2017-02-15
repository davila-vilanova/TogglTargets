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

    internal var didSelectProject: ( (Project) -> () )?

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
        projectsCollectionView.delegate = self
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
        if let projects = self.projects,
            !projects.isEmpty,
            projectsCollectionView.selectionIndexes.isEmpty {
            projectsCollectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: .top)
            didSelectProject?(projects[0])
        }
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
        let project = projects?[indexPath.item]
        projectItem.projectName = project?.name
        if let projectId = project?.id {
            projectItem.goalProperty = modelCoordinator?.goalPropertyForProjectId(projectId)
            projectItem.reportProperty = modelCoordinator?.reportPropertyForProjectId(projectId)
        }
        return projectItem
    }

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let index = indexPaths.first?.item,
            let project = projects?[index] {
            didSelectProject?(project)
        }
    }
}
