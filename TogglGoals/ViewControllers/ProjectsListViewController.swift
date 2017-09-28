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

    internal var projectsByGoals: BindingTarget<ProjectsByGoals> { return _projectsByGoals.deoptionalizedBindingTarget }
    internal var fullProjectsUpdate: BindingTarget<Bool> { return _fullProjectsUpdate.deoptionalizedBindingTarget }
    internal var cluedProjectsUpdate: BindingTarget<CollectionUpdateClue> { return _cluedProjectsUpdate.deoptionalizedBindingTarget }

    internal lazy var selectedProject = Property<Project?>(_selectedProject)


    // MARK: - Backing properties

    private let _projectsByGoals = MutableProperty<ProjectsByGoals?>(nil)
    private let _fullProjectsUpdate = MutableProperty<Bool?>(nil)
    private let _cluedProjectsUpdate = MutableProperty<CollectionUpdateClue?>(nil)
    private let _selectedProject = MutableProperty<Project?>(nil)


    // MARK: - Goal and report providing

    // TODO: Generalize and encapsulate?
    internal var goalReadProviderProducer: SignalProducer<Action<Int64, Property<Goal?>, NoError>, NoError>! {
        didSet {
            assert(goalReadProviderProducer != nil)
            assert(oldValue == nil)
            if let producer = goalReadProviderProducer {
                goalReadProvider <~ producer.take(first: 1)
            }
        }
    }
    private let goalReadProvider = MutableProperty<Action<Int64, Property<Goal?>, NoError>?>(nil)

    internal var reportReadProviderProducer: SignalProducer<Action<Int64, Property<TwoPartTimeReport?>, NoError>, NoError>! {
        didSet {
            assert(reportReadProviderProducer != nil)
            assert(oldValue == nil)
            if let producer = reportReadProviderProducer {
                reportReadProvider <~ producer.take(first: 1)
            }
        }
    }
    private let reportReadProvider = MutableProperty<Action<Int64, Property<TwoPartTimeReport?>, NoError>?>(nil)


    // MARK: Outlets

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

        let providersProducer = SignalProducer.combineLatest(goalReadProvider.producer.skipNil().take(first: 1),
                                                             reportReadProvider.producer.skipNil().take(first: 1))
        providersProducer.combineLatest(with: _fullProjectsUpdate.producer.skipNil().filter { $0 })
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] (_) in
                self.reloadList()
        }
        providersProducer.combineLatest(with: _cluedProjectsUpdate.producer.skipNil())
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] (_, clue) in
                self.updateList(with: clue)
        }
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
        _selectedProject.value = _projectsByGoals.value?.project(for: indexPath)
    }

    private func scrollToSelection() {
        assert(Thread.current.isMainThread)
        projectsCollectionView.animator().scrollToItems(at: projectsCollectionView.selectionIndexPaths, scrollPosition: .nearestHorizontalEdge)
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return ProjectsByGoals.Section.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let projectsByGoalsValue = _projectsByGoals.value

        switch ProjectsByGoals.Section(rawValue: section)! {
        case .withGoal: return projectsByGoalsValue?.idsOfProjectsWithGoals.count ?? 0
        case .withoutGoal: return projectsByGoalsValue?.idsOfProjectsWithoutGoals.count ?? 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ProjectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem

        // TODO: what would happen if the value of projectsByGoals changed while the CollectionView is updating its contents?
        let project = _projectsByGoals.value!.project(for: indexPath)!
        projectItem.currentProject = project
        projectItem.goals <~ goalReadProvider.value!.apply(project.id).mapToNoError()
        projectItem.reports <~ reportReadProvider.value!.apply(project.id).mapToNoError()

        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: SectionHeaderIdentifier, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            switch ProjectsByGoals.Section(rawValue: indexPath.section)! {
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
