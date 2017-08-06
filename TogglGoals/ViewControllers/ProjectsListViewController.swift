//
//  ProjectsListViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift

enum SectionIndex: Int {
    case projectsWithGoals = 0
    case projectsWithoutGoals
}
fileprivate let NumberOfSections = 2

class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, ModelCoordinatorContaining {
    private let projectItemIdentifier = NSUserInterfaceItemIdentifier("ProjectItemIdentifier")
    private let sectionHeaderIdentifier = NSUserInterfaceItemIdentifier("SectionHeaderIdentifier")

    private let uiScheduler = UIScheduler()

    internal var didSelectProject: ( (Project?) -> () )?

    var modelCoordinator: ModelCoordinator? {
        didSet {
            if (isViewLoaded) {
                bindToProjects()
            }
        }
    }

    @IBOutlet weak var projectsCollectionView: NSCollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        projectsCollectionView.dataSource = self
        projectsCollectionView.delegate = self

        let itemNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewItem"), bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: projectItemIdentifier)

        let headerNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewHeader"), bundle: nil)!
        projectsCollectionView.register(headerNib, forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: sectionHeaderIdentifier)
        
        bindToProjects()
    }

    private func bindToProjects() {
        guard let modelCoordinator = modelCoordinator else {
            return
        }

        modelCoordinator.fullProjectsUpdateSignal.observe(on: uiScheduler).observeValues { [weak self] _ in
            self?.refresh()
        }

        modelCoordinator.cluedProjectsUpdateSignal.observe(on: uiScheduler).observeValues { [weak self] (clue) in
            self?.refresh(with: clue)
        }
    }

    fileprivate func refresh(with providedClue: CollectionUpdateClue? = nil) {
        guard let clue = providedClue else {
            projectsCollectionView.reloadData()
            updateSelection()
            return
        }
        if let moved = clue.movedItems {
            for (oldIndexPath, newIndexPath) in moved {
                projectsCollectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
            }
        }

        // First delete items at old index paths, then add items at new index paths
        if let removed = clue.removedItems {
            projectsCollectionView.animator().deleteItems(at: removed)
        }
        if let added = clue.addedItems {
            projectsCollectionView.animator().insertItems(at: added)
        }
     }
    
    private func updateSelection() {
        guard let didSelectProject = self.didSelectProject else {
            return
        }
        
        guard let indexPath = projectsCollectionView.selectionIndexPaths.first else {
            didSelectProject(nil)
            return
        }

        didSelectProject(modelCoordinator?.projects.project(for: indexPath))
    }
    
    
    // MARK: - NSCollectionViewDataSource
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return NumberOfSections
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let projectsByGoals = modelCoordinator?.projects else {
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
        
        if let project = modelCoordinator?.projects.project(for: indexPath) {
            projectItem.projectName = project.name
            projectItem.goalProperty = modelCoordinator?.goalProperty(for: project.id)
            projectItem.reportProperty = modelCoordinator?.reportProperty(for: project.id)
        }
        
        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: sectionHeaderIdentifier, for: indexPath)
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
