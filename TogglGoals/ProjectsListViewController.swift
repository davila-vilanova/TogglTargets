//
//  ProjectsListViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, ModelCoordinatorContaining {
    private let projectItemIdentifier = "ProjectItemIdentifier"
    private let sectionHeader = "SectionHeader"
    
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

        let itemNib = NSNib(nibNamed: "ProjectCollectionViewItem", bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: projectItemIdentifier)

        let headerNib = NSNib(nibNamed: "ProjectCollectionViewHeader", bundle: nil)!
        projectsCollectionView.register(headerNib, forSupplementaryViewOfKind: NSCollectionElementKindSectionHeader, withIdentifier: sectionHeader)
        
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
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 2
    }
    
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

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionElementKindSectionHeader, withIdentifier: sectionHeader, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            header.title = "all projects"
        }
        return view
    }
    
    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }
}
