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

fileprivate let ProjectItemIdentifier = NSUserInterfaceItemIdentifier("ProjectItemIdentifier")
fileprivate let SectionHeaderIdentifier = NSUserInterfaceItemIdentifier("SectionHeaderIdentifier")

class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate {

    // MARK: - Exposed targets and source

    internal var projects: BindingTarget<IndexedProjects> { return _projects.deoptionalizedBindingTarget }
    internal var goals: BindingTarget<ProjectIndexedGoals> { return _goals.deoptionalizedBindingTarget }
    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }
    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }

    internal lazy var selectedProject = Property<Project?>(_selectedProject)


    // MARK: - Backing properties

    private let _projects = MutableProperty<IndexedProjects?>(nil)
    private let _goals = MutableProperty<ProjectIndexedGoals?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _now = MutableProperty<Date?>(nil)
    private let _selectedProject = MutableProperty<Project?>(nil)


    // MARK: - Goal and report providing

    internal var readGoalAction: Action<ProjectID, Property<Goal?>, NoError>!
    internal var readReportAction : Action<ProjectID, Property<TwoPartTimeReport?>, NoError>!


    // MARK: Preparing collection view data

    enum Section: Int {
        case withGoal = 0
        case withoutGoal = 1

        static var count = 2
    }

    private struct CollectionViewMetadata {
        private let projectIdsToIndexPaths: [Int64 : IndexPath]
        private let indexPathsToProjectIds: [IndexPath : Int64]
        let countOfProjectsWithGoals: Int
        let countOfProjectsWithoutGoals: Int
        let projectIdsWithChangedGoals: [Int64]

        init(projects: IndexedProjects, goals: ProjectIndexedGoals, previousGoals: ProjectIndexedGoals?) {
            let changesInGoals = goals.keysOfDifferingValues(with: previousGoals)
            let sortedIds: [Int64] = [Int64](projects.keys).sorted(by: { (idA, idB) -> Bool in
                let goalA = goals[idA]
                let goalB = goals[idB]

                if goalA != nil, goalB == nil {
                    // a goal is more goaler than a no goal
                    return true
                } else if let a = goalA, let b = goalB {
                    // the larger goal comes first
                    return a > b
                } else {
                    return false
                }
            })
            let idsOfProjectsWithGoals: ArraySlice<Int64> = sortedIds.prefix { (projectId) -> Bool in
                return goals[projectId] != nil
            }
            let idsOfProjectsWithoutGoals = sortedIds.suffix(from: idsOfProjectsWithGoals.count)

            var idsToIndexPaths = [Int64 : IndexPath]()
            var indexPathsToIds = [IndexPath : Int64]()
            for (index, projectId) in idsOfProjectsWithGoals.enumerated() {
                let indexPath = IndexPath(item: index, section: Section.withGoal.rawValue)
                idsToIndexPaths[projectId] = indexPath
                indexPathsToIds[indexPath] = projectId
            }
            for (index, projectId) in idsOfProjectsWithoutGoals.enumerated() {
                let indexPath = IndexPath(item: index, section: Section.withoutGoal.rawValue)
                idsToIndexPaths[projectId] = indexPath
                indexPathsToIds[indexPath] = projectId
            }

            projectIdsToIndexPaths = idsToIndexPaths
            indexPathsToProjectIds = indexPathsToIds
            countOfProjectsWithGoals = idsOfProjectsWithGoals.count
            countOfProjectsWithoutGoals = idsOfProjectsWithoutGoals.count
            self.projectIdsWithChangedGoals = changesInGoals
        }

        func indexPath(for projectId: Int64) -> IndexPath? {
            return projectIdsToIndexPaths[projectId]
        }

        func projectId(for indexPath: IndexPath) -> Int64? {
            return indexPathsToProjectIds[indexPath]
        }
    }

    private lazy var metadata: MutableProperty<CollectionViewMetadata?> = {
        let p = MutableProperty<CollectionViewMetadata?>(nil)

        p <~ SignalProducer.combineLatest(_projects.producer.skipNil(), _goals.producer.combinePrevious())
            .map { (input) -> CollectionViewMetadata? in
                let (projects, (previousGoals, currentGoals)) = input
                guard let goals = currentGoals else {
                    return nil
                }
                return CollectionViewMetadata(projects: projects, goals: goals, previousGoals: previousGoals)
        }

        return p
    }()

    private let (lifetime, token) = Lifetime.make()

    private lazy var reloadList = BindingTarget<()>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (_) in
        self.projectsCollectionView.reloadData()
        self.updateSelection()
        self.scrollToSelection()
    }

    private lazy var updateList =
        BindingTarget<(CollectionViewMetadata, CollectionViewMetadata)>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (previousMetadata, currentMetadata) in
            // Having the project IDs for the goal(s) whose change prompted the current update makes it simple to
            // move only the items directly affected by the changes.
            for projectId in currentMetadata.projectIdsWithChangedGoals {
                let oldIndexPath = previousMetadata.indexPath(for: projectId)!
                let newIndexPath = currentMetadata.indexPath(for: projectId)!
                guard oldIndexPath != newIndexPath else {
                    continue
                }
                self.projectsCollectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
            }
    }

    // MARK: - Outlets

    @IBOutlet weak var projectsCollectionView: NSCollectionView!


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        projectsCollectionView.dataSource = self
        projectsCollectionView.delegate = self

        let itemNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewItem"), bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: ProjectItemIdentifier)

        let headerNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewHeader"), bundle: nil)!
        projectsCollectionView.register(headerNib, forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: SectionHeaderIdentifier)

        reloadList <~ metadata.producer.skipNil().filter { $0.projectIdsWithChangedGoals.count == 0 }.map { _ in return () }

        updateList <~ metadata.producer.skipNil().combinePrevious().filter { (_, currentMetadata) in currentMetadata.projectIdsWithChangedGoals.count > 0 }
    }

    private func updateSelection() {
        _selectedProject.value = {
            guard let indexPath = projectsCollectionView.selectionIndexPaths.first else {
                return nil
            }
            guard let projectId = metadata.value?.projectId(for: indexPath) else {
                return nil
            }
            return _projects.value?[projectId]
        }()
    }

    private func scrollToSelection() {
        assert(Thread.current.isMainThread)
        projectsCollectionView.animator().scrollToItems(at: projectsCollectionView.selectionIndexPaths, scrollPosition: .nearestHorizontalEdge)
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return Section.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .withGoal: return metadata.value?.countOfProjectsWithGoals ?? 0
        case .withoutGoal: return metadata.value?.countOfProjectsWithoutGoals ?? 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ProjectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem
        projectItem.connectOnceInLifecycle(runningEntry: _runningEntry.producer, now: _now.producer.skipNil())

        let projectId: ProjectID = metadata.value!.projectId(for: indexPath)!

        // Extract from the _projects property a property for the single project identified by projectId
        let projectProperty: Property<Project?> = _projects.map { $0?[projectId] }
        projectItem.projects <~ SignalProducer<Property<Project?>, NoError>(value: projectProperty)
        projectItem.goals <~ readGoalAction.applySerially(projectId)
        projectItem.reports <~ readReportAction.applySerially(projectId)

        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: SectionHeaderIdentifier, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            switch Section(rawValue: indexPath.section)! {
            case .withGoal: header.title = "projects with goals"
            case .withoutGoal: header.title = "projects without goals"
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

// MARK: -

fileprivate extension Dictionary where Value: Equatable {
    func keysOfDifferingValues(with anotherDictionaryOrNil: Dictionary<Key, Value>?) -> [Key] {
        var diffKeys = [Key]()

        guard let otherness = anotherDictionaryOrNil else {
            return diffKeys
        }

        let allKeys = Set<Key>(self.keys).union(otherness.keys)
        for key in allKeys {
            if self[key] != otherness[key] {
                diffKeys.append(key)
            }
        }
        return diffKeys
    }
}
