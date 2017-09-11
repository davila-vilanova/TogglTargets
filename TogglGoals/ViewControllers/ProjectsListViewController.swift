//
//  ProjectsListViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

enum SectionIndex: Int {
    case projectsWithGoals = 0
    case projectsWithoutGoals
}
fileprivate let NumberOfSections = 2

class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private let projectItemIdentifier = NSUserInterfaceItemIdentifier("ProjectItemIdentifier")
    private let sectionHeaderIdentifier = NSUserInterfaceItemIdentifier("SectionHeaderIdentifier")

    private let uiScheduler = UIScheduler()

    private var modelCoordinatorObservationDisposables = [Disposable]()
    var modelCoordinator: ModelCoordinator? {
        didSet {
            modelCoordinatorObservationDisposables.forEach { disposable in
                disposable.dispose()
            }
            modelCoordinatorObservationDisposables.removeAll()

            guard let mc = modelCoordinator else {
                return
            }

            func observeValues<T>(from signal: Signal<T, NoError>, _ action: @escaping (T) -> ()) {
                if let disposable = signal.observe(on: uiScheduler).observeValues(action) {
                    modelCoordinatorObservationDisposables.append(disposable)
                }
            }

            observeValues(from: mc.fullProjectsUpdate) { [weak self] _ in
                self?.reloadList()
            }
            observeValues(from: mc.cluedProjectsUpdate) { [weak self] clue in
                self?.updateList(with: clue)
            }
        }
    }

    internal var selectedProject = MutableProperty<Project?>(nil)

    @IBOutlet weak var projectsCollectionView: NSCollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        projectsCollectionView.dataSource = self
        projectsCollectionView.delegate = self

        let itemNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewItem"), bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: projectItemIdentifier)

        let headerNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewHeader"), bundle: nil)!
        projectsCollectionView.register(headerNib, forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: sectionHeaderIdentifier)

        reloadList()
    }

    private func reloadList() {
        projectsCollectionView.reloadData()
        updateSelection()
        scrollToSelection()
    }

    private func updateList(with clue: CollectionUpdateClue) {
        // First move items that have moved, then delete items at old index paths, finally add items at new index paths
        if let moved = clue.movedItems {
            for (oldIndexPath, newIndexPath) in moved {
                projectsCollectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
            }
        }
        if let removed = clue.removedItems {
            projectsCollectionView.animator().deleteItems(at: removed)
        }
        if let added = clue.addedItems {
            projectsCollectionView.animator().insertItems(at: added)
        }

        scrollToSelection()
     }

    private func updateSelection() {
        let indexPath = projectsCollectionView.selectionIndexPaths.first
        selectedProject.value = modelCoordinator?.projectsByGoals.project(for: indexPath)
    }

    private func scrollToSelection() {
        assert(Thread.current.isMainThread)
        projectsCollectionView.animator().scrollToItems(at: projectsCollectionView.selectionIndexPaths, scrollPosition: .nearestHorizontalEdge)
    }

    // MARK: - NSCollectionViewDataSource
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return NumberOfSections
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let projectsByGoals = modelCoordinator?.projectsByGoals else {
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

        let modelCoordinator = self.modelCoordinator!
        let project = modelCoordinator.projectsByGoals.project(for: indexPath)!
        projectItem.bindExclusivelyTo(project: project,
                                      goal: modelCoordinator.goalProperty(for: project.id),
                                      report: modelCoordinator.reportProperty(for: project.id))

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
