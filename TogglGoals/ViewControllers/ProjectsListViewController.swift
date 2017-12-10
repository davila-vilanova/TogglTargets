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

    private let (lifetime, token) = Lifetime.make()


    // MARK: - Exposed targets and source

    internal lazy var projectIDsByGoals = // TODO: should be an action that can fail and be retried
        BindingTarget<ProjectIDsByGoals.Update>(on: UIScheduler(), lifetime: lifetime) { [unowned self] update in
            switch update {
            case .full(let projectIDs):
                self.refresh(with: projectIDs)
            case .createGoal(let goalUpdate):
                self.update(with: goalUpdate)
            }
    }

    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }
    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }

    internal lazy var selectedProject = Property<Project?>(_selectedProject)


    // MARK: - Backing properties

    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _now = MutableProperty<Date?>(nil)
    private let _selectedProject = MutableProperty<Project?>(nil)


    // MARK: - Actions

    internal var readProjectAction: Action<ProjectID, Property<Project?>, NoError>!
    internal var readGoalAction: ReadGoalAction!
    internal var readReportAction: Action<ProjectID, Property<TwoPartTimeReport?>, NoError>!


    // MARK: - Outlets

    @IBOutlet weak var projectsCollectionView: NSCollectionView!


    // MARK: -

    private var currentProjectIDs = ProjectIDsByGoals.empty

    override func viewDidLoad() {
        super.viewDidLoad()

        projectsCollectionView.dataSource = self
        projectsCollectionView.delegate = self

        let itemNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewItem"), bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: ProjectItemIdentifier)

        let headerNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewHeader"), bundle: nil)!
        projectsCollectionView.register(headerNib,
                                        forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader,
                                        withIdentifier: SectionHeaderIdentifier)
    }

    private func refresh(with projectIDs: ProjectIDsByGoals) {
        self.currentProjectIDs = projectIDs
        self.projectsCollectionView.reloadData()
        self.updateSelection()
        self.scrollToSelection()
    }

    private func update(with update: ProjectIDsByGoals.Update.GoalUpdate) {
        let beforeMove = self.currentProjectIDs
        let afterMove = update.apply(to: beforeMove)
        let oldIndexPath = beforeMove.indexPath(forElementAt: update.indexChange.old)!
        let newIndexPath = afterMove.indexPath(forElementAt: update.indexChange.new)!

        self.currentProjectIDs = afterMove
        self.projectsCollectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
        self.scrollToSelection()
    }

    private func updateSelection() {
        _selectedProject <~ { () -> SignalProducer<Project?, NoError> in
            guard let indexPath = projectsCollectionView.selectionIndexPaths.first,
                let projectId = currentProjectIDs.projectId(for: indexPath) else {
                    return SignalProducer(value: nil)
            }
            return readProjectAction.applySerially(projectId).flatten(.latest)
        }()
    }

    private func scrollToSelection() {
        assert(Thread.current.isMainThread)
        projectsCollectionView.animator()
            .scrollToItems(at: projectsCollectionView.selectionIndexPaths,
                           scrollPosition: .nearestHorizontalEdge)
    }


    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return ProjectIDsByGoals.Section.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        switch ProjectIDsByGoals.Section(rawValue: section)! {
        case .withGoal: return currentProjectIDs.countOfProjectsWithGoals
        case .withoutGoal: return currentProjectIDs.countOfProjectsWithoutGoals
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ProjectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem
        projectItem.connectOnceInLifecycle(runningEntry: _runningEntry.producer,
                                           now: _now.producer.skipNil())

        let projectId: ProjectID = currentProjectIDs.projectId(for: indexPath)!

        projectItem.projects <~ readProjectAction.applySerially(projectId)
        projectItem.goals <~ readGoalAction.applySerially(projectId)
        projectItem.reports <~ readReportAction.applySerially(projectId)

        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader,
                                                        withIdentifier: SectionHeaderIdentifier, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            switch ProjectIDsByGoals.Section(rawValue: indexPath.section)! {
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
