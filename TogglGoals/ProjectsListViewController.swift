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
        projectsCollectionView.register(headerNib, forSupplementaryViewOfKind: NSCollectionElementKindSectionHeader, withIdentifier: sectionHeaderIdentifier)
        
        bindToProjects()
    }

    private var observedProjects: ObservedProperty<ProjectsByGoals>?
    
    private func bindToProjects() {
        guard observedProjects == nil,
            let projectsProperty = modelCoordinator?.projectsProperty else {
            return
        }
        
        observedProjects =
            ObservedProperty<ProjectsByGoals>(original: projectsProperty,
                                              valueObserver: { [weak self] (projects) in
                                                self?.projectsByGoals = projects
                },
                                              invalidationObserver: { [weak self] in
                                                self?.observedProjects = nil
            })
    }

    func refresh() {
        projectsCollectionView.reloadData()
        updateSelection()
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
        return 2
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let projectsByGoals = projectsByGoals else {
            return 0
        }
        switch section {
        case 0: return projectsByGoals.idsOfProjectsWithGoals.count
        case 1: return projectsByGoals.idsOfProjectsWithoutGoals.count
        default: return 0
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
            switch indexPath.section {
            case 0: header.title = "projects with goals"
            case 1: header.title = "projects without goals"
            default: print("unexpected section in indexPath (\(indexPath))")
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
