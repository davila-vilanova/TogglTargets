//
//  ProjectsListViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa


enum SectionIndex: Int {
    case projectsWithGoals = 0
    case projectsWithoutGoals
}
fileprivate let NumberOfSections = 2

class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, ModelCoordinatorContaining {
    private let projectItemIdentifier = "ProjectItemIdentifier"
    private let sectionHeaderIdentifier = "SectionHeaderIdentifier"
    
    internal var didSelectProject: ( (Project?) -> () )?

    var modelCoordinator: ModelCoordinator? {
        didSet {
            if (isViewLoaded) {
                bindToProjects()
            }
        }
    }

    var projectsByGoals: ProjectsByGoals? {
        didSet {
            if let old = oldValue, let new = projectsByGoals {
                let diff = ProjectListUpdateDiff(oldProjectsValue: old, newProjectsValue: new)
                refresh(with: diff)
            } else {
                refresh()
            }
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
        projectsCollectionView.register(headerNib, forSupplementaryViewOfKind: NSCollectionElementKindSectionHeader, withIdentifier: sectionHeaderIdentifier)
        
        bindToProjects()
    }

    private var observedProjects: ObservedProperty<ProjectsByGoals>?
    
    private func bindToProjects() {
        guard observedProjects == nil,
            let projectsProperty = modelCoordinator?.projects else {
            return
        }
        
        observedProjects =
            ObservedProperty<ProjectsByGoals>(original: projectsProperty,
                                              valueObserver: { [weak self] (op) in
                                                self?.projectsByGoals = op.original?.value
                },
                                              invalidationObserver: { [weak self] in
                                                self?.observedProjects = nil
            })
    }

    fileprivate func refresh(with providedDiff: ProjectListUpdateDiff? = nil) {
        guard let diff = providedDiff else {
            projectsCollectionView.reloadData()
            updateSelection()
            return
        }
        for (oldIndexPath, newIndexPath) in diff.movedItems {
            projectsCollectionView.moveItem(at: oldIndexPath, to: newIndexPath)
        }
        // First delete items at old index paths, then add items at new index paths
        projectsCollectionView.deleteItems(at: diff.removedItems)
        projectsCollectionView.insertItems(at: diff.addedItems)
     }

    
    private func updateSelection() {
        guard let didSelectProject = self.didSelectProject else {
            return
        }
        
        guard let indexPath = projectsCollectionView.selectionIndexPaths.first else {
            didSelectProject(nil)
            return
        }
        
        didSelectProject(projectsByGoals?.project(for: indexPath))
    }
    
    
    // MARK: - NSCollectionViewDataSource
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return NumberOfSections
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let projectsByGoals = projectsByGoals else {
            return 0
        }
        switch SectionIndex(rawValue: section)! {
        case .projectsWithGoals: return projectsByGoals.idsOfProjectsWithGoals.count
        case .projectsWithoutGoals: return projectsByGoals.idsOfProjectsWithoutGoals.count
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: projectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem
        
        if let project = projectsByGoals?.project(for: indexPath) {
            projectItem.projectName = project.name
            projectItem.goalProperty = modelCoordinator?.goalProperty(for: project.id)
            projectItem.reportProperty = modelCoordinator?.reportProperty(for: project.id)
        }
        
        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionElementKindSectionHeader, withIdentifier: sectionHeaderIdentifier, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            switch SectionIndex(rawValue: indexPath.section)! {
            case .projectsWithGoals: header.title = "projects with goals"
            case .projectsWithoutGoals: header.title = "projects without goals"
            }

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

struct ProjectListUpdateDiff {
    let movedItems: Dictionary<IndexPath, IndexPath>
    let removedItems: Set<IndexPath>
    let addedItems: Set<IndexPath>
    
    init(oldProjectsValue: ProjectsByGoals, newProjectsValue: ProjectsByGoals) {
        var newIndexPathsByProjectId = Dictionary<Int64, IndexPath>()
        for newIndex in newProjectsValue.sortedProjectIds.startIndex ..< newProjectsValue.sortedProjectIds.endIndex {
            let projectId = newProjectsValue.sortedProjectIds[newIndex]
            let newIndexPath = newProjectsValue.indexPath(for: newIndex)!
            newIndexPathsByProjectId[projectId] = newIndexPath
        }
        
        var movedIndexPaths = Dictionary<IndexPath, IndexPath>()
        var oldIndexPathsOfRemovedItems = Set<IndexPath>()
        for oldIndex in oldProjectsValue.sortedProjectIds.startIndex ..< oldProjectsValue.sortedProjectIds.endIndex {
            let projectId = oldProjectsValue.sortedProjectIds[oldIndex]
            let oldIndexPath = oldProjectsValue.indexPath(for: oldIndex)!
            if let newIndexPath = newIndexPathsByProjectId.removeValue(forKey: projectId) {
                if oldIndexPath != newIndexPath {
                    movedIndexPaths[oldIndexPath] = newIndexPath
                }
            } else {
                oldIndexPathsOfRemovedItems.insert(oldIndexPath)
            }
        }
        
        movedItems = movedIndexPaths
        removedItems = oldIndexPathsOfRemovedItems
        addedItems = Set<IndexPath>(newIndexPathsByProjectId.values) // Remaining ones - not removed in previous step
    }
}
