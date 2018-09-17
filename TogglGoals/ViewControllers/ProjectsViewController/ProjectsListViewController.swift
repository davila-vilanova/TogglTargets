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

fileprivate let SelectedProjectIdRestorationKey = "SelectedProjectId"
fileprivate let NoSelectedProjectIdRestorationValue: Int64 = 0


/// Manages a collection view that displays `Project` items organized by whether they have an associated goal.
/// Produces a stream of selected `Project` values via the `selectedProject` property.
class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, BindingTargetProvider {

    // MARK: - Interface

    ///   - projectIDsByGoals: a producer of `ProjectIDsByGoals.Update` values
    ///     that when started emits a `full(ProjectIDsByGoals)` value which can
    ///     be followed by full or incremental updates.
    ///     Full values cause a full refresh. Incremental updates cause a reorder of projects in the
    ///     displayed collection.
    ///   - selectedProjectId:  Emits `Project` values whenever a project is selected
    ///     or `nil` when no project is selected. Only one project can be selected at a time.
    ///   - runningEntry: A signal producer that emits `RunningEntry` or `nil` values depending on whether
    ///     a time entry is currently active. This is used to add the currently running time to the reported
    ///     worked time for the corresponding project.
    ///   - currentDate: A signal producer that emits `Date` values corresponding to the current date as time passes.
    ///     This is useful to calculate the elapsed running time of the active time entry provided by `runningEntry`.
    ///   - readProject: A function this controller will use to read projects corresponding
    ///     to its input project IDs.
    ///   - readGoal: A function this controller will use to read goals corresponding
    ///     to its input project IDs.
    ///   - readReport: A function this controller will use to read `TwoPartTimeReport`s corresponding
    ///     to its input project IDs.
    internal typealias Interface = (
        projectIDsByGoals: ProjectIDsByGoalsProducer,
        selectedProjectId: BindingTarget<ProjectID?>,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        readProject: ReadProject,
        readGoal: ReadGoal,
        readReport: ReadReport)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Backing properties

    /// Holds the input `RunningEntry` values.
    private let runningEntry = MutableProperty<RunningEntry?>(nil)

    /// Holds the current `Date` input values.
    private let currentDate = MutableProperty<Date?>(nil)

    private let periodPreference = MutableProperty<PeriodPreference?>(nil)

    /// Holds the ID of the currently selected project, if any.
    private let selectedProjectID = MutableProperty<ProjectID?>(nil)

    /// The function used to read projects by project ID.
    private let readProject = MutableProperty<ReadProject?>(nil)

    /// The function used to read goals by project ID.
    private let readGoal = MutableProperty<ReadGoal?>(nil)

    /// The action used to read reports by project ID.
    private let readReport = MutableProperty<ReadReport?>(nil)

    // MARK: - Private properties

    /// The current value of `ProjectsIDsByGoals`.
    private var currentProjectIDs = MutableProperty(ProjectIDsByGoals.empty)

    private var lastProjectIDsByGoalsUpdate = MutableProperty<ProjectIDsByGoals.Update?>(nil)


    // MARK: - Outlets

    /// The collection view in charge of displaying the projects organized by goals following the
    /// project ID order and the structure of the current `ProjectIDsByGoals` value.
    @IBOutlet weak var projectsCollectionView: NSCollectionView!


    // MARK: - State restoration

    private let restoredSelectedProjectId = MutableProperty<ProjectID?>(nil)

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode((selectedProjectID.value ?? NoSelectedProjectIdRestorationValue) as Int64, forKey: SelectedProjectIdRestorationKey)
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        let restoredSelectedProjectId = coder.decodeInt64(forKey: SelectedProjectIdRestorationKey)
        self.restoredSelectedProjectId.value = restoredSelectedProjectId == NoSelectedProjectIdRestorationValue ? nil : restoredSelectedProjectId
    }

    private func invalidateRestorableStateWhenProjectManuallySelected() {
        reactive.makeBindingTarget { controller, _ in
            controller.invalidateRestorableState()
            } <~  selectedProjectID
    }

    private func restoreSelectionInCollectionView() {
        let projectManuallySelected = selectedProjectID.signal.map { _ in () }

        let selectIndexPath = reactive.makeBindingTarget { controller, indexPath in
            controller.projectsCollectionView.selectItems(at: [indexPath], scrollPosition: .centeredVertically)
        }

        let indexPathFromPersistedProjectId = SignalProducer.combineLatest(currentProjectIDs, restoredSelectedProjectId)
            .take(until: projectManuallySelected)
            .filterMap { (currentProjectIds, restoredProjectId) -> IndexPath? in
                guard let projectId = restoredProjectId else {
                    return nil
                }
                return currentProjectIds.indexPath(for: projectId)
            }
            .take(first: 1)

        reactive.lifetime += selectIndexPath <~ indexPathFromPersistedProjectId
    }


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeProjectsCollectionView()
        wireUpdatesToCollectionView()

        lastProjectIDsByGoalsUpdate <~ lastBinding.latestOutput { $0.projectIDsByGoals }
        runningEntry <~ lastBinding.latestOutput { $0.runningEntry }
        currentDate <~ lastBinding.latestOutput { $0.currentDate }
        periodPreference <~ lastBinding.latestOutput { $0.periodPreference }

        let lastValidBinding = lastBinding.producer.skipNil()
        readProject <~ lastValidBinding.map { $0.readProject }
        readGoal <~ lastValidBinding.map { $0.readGoal }
        readReport <~ lastValidBinding.map { $0.readReport }

        let selectedProjectId = restoredSelectedProjectId.producer.take(untilReplacement: self.selectedProjectID.signal)
        reactive.lifetime += selectedProjectId.bindOnlyToLatest(lastValidBinding.map { $0.selectedProjectId })

        invalidateRestorableStateWhenProjectManuallySelected()
        restoreSelectionInCollectionView()
    }

    private func initializeProjectsCollectionView() {
        let itemNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewItem"), bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: ProjectItemIdentifier)

        let headerNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewHeader"), bundle: nil)!
        projectsCollectionView.register(headerNib,
                                        forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader,
                                        withIdentifier: SectionHeaderIdentifier)

        let layout = projectsCollectionView.collectionViewLayout as! VerticalListLayout
        layout.headerReferenceSize = CGSize(width: projectsCollectionView.bounds.width, height: 42)
        layout.sectionHeadersPinToVisibleBounds = true
    }

    private func wireUpdatesToCollectionView() {
        // wire full updates: set the current value of `currentProjectIDs`
        // and trigger a full refresh of the collection view
        let fullUpdates = lastProjectIDsByGoalsUpdate.producer.skipNil().filterMap { $0.fullyUpdated }

        currentProjectIDs <~ fullUpdates

        reactive.makeBindingTarget { controller, _ in
            controller.projectsCollectionView.reloadData()
            controller.scrollToSelection()
        } <~ fullUpdates.map { _ in () }


        // wire single goal updates: reflect the provided update in the value of `currentProjectIDs`,
        // reorder the affected item in the collection view and update the "last item in section" visual state
        let singlePidsUpdates: Signal<(ProjectIDsByGoals.Update.GoalUpdate, ProjectIDsByGoals, ProjectIDsByGoals), NoError> =
            lastProjectIDsByGoalsUpdate.signal.skipNil().filterMap { $0.goalUpdate }
                .withLatest(from: currentProjectIDs.producer)
                .map { ($0.0, $0.1, $0.0.apply(to: $0.1)) }
        let indexPathUpdates = singlePidsUpdates.map { update, pidsBefore, pidsAfter -> (IndexPath, IndexPath) in
            guard let old = pidsBefore.indexPath(forElementAt: update.indexChange.old),
                let new = pidsAfter.indexPath(forElementAt: update.indexChange.new) else {
                    fatalError("Old and new index paths are expected to be calculable")
            }
            return (old, new)
        }

        let newIndexPaths = indexPathUpdates.map { $0.1 }
        let updatedPids = singlePidsUpdates.map { $0.2 }
        let itemsWhoseLastInSectionStatusMustUpdate = newIndexPaths.zip(with: updatedPids)
            .map { (newIndexPath, updatedPids) -> Dictionary<IndexPath, Bool> in
                var possiblyAffectedItems: Set<IndexPath> = [newIndexPath,
                                                             updatedPids.indexPathOfLastItem(in: ProjectIDsByGoals.Section.withGoal),
                                                             updatedPids.indexPathOfLastItem(in: ProjectIDsByGoals.Section.withoutGoal)]

                if let section = ProjectIDsByGoals.Section.init(rawValue: newIndexPath.section),
                    newIndexPath == updatedPids.indexPathOfLastItem(in: section),
                    newIndexPath.item > 0 {
                    possiblyAffectedItems.insert(IndexPath(item: newIndexPath.item - 1, section: newIndexPath.section))
                }

                var withValues = Dictionary<IndexPath, Bool>()
                for indexPath in possiblyAffectedItems {
                    withValues[indexPath] = updatedPids.isIndexPathOfLastItemInSection(indexPath)
                }
                return withValues
        }

        // update values
        currentProjectIDs <~ updatedPids

        // move items as needed, but ensure the collection view is asked to move the items only after
        // currentProjectIDs is updated as a result of receiving a single goal update
        projectsCollectionView.reactive.makeBindingTarget { collectionView, indexPaths in
            let (oldIndexPath, newIndexPath) = indexPaths
            collectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
            } <~ indexPathUpdates

        projectsCollectionView.reactive.makeBindingTarget { collectionView, itemsToUpdate in
            for (indexPath, isLastInSection) in itemsToUpdate {
                if let item = collectionView.item(at: indexPath) as? ProjectCollectionViewItem { // will only determine the status of already cached items
                    item.isLastItemInSection = isLastInSection
                }
            }
            } <~ itemsWhoseLastInSectionStatusMustUpdate // update "last in section" visual state
    }

    /// Scrolls the collection view to display the currently selected item.
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
                        numberOfItemsInSection rawSection: Int) -> Int {
        guard let section = ProjectIDsByGoals.Section(rawValue: rawSection) else {
            return 0
        }
        return currentProjectIDs.value.numberOfItems(in: section)
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ProjectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem

        let projectId: ProjectID = currentProjectIDs.value.projectId(for: indexPath)!

        projectItem <~ SignalProducer<ProjectCollectionViewItem.Interface, NoError>(
            value: (runningEntry.producer,
                    currentDate.producer.skipNil(),
                    readProject.value!(projectId),
                    readGoal.value!(projectId),
                    periodPreference.producer.skipNil(),
                    readReport.value!(projectId)))

        projectItem.isLastItemInSection = currentProjectIDs.value.isIndexPathOfLastItemInSection(indexPath)

        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader,
                                                        withIdentifier: SectionHeaderIdentifier, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            switch ProjectIDsByGoals.Section(rawValue: indexPath.section)! {
            case .withGoal: header.title = NSLocalizedString("project-list.header.with-goals",
                                                             comment: "header of the 'projects with goals' section of the project list")
            case .withoutGoal: header.title = NSLocalizedString("project-list.header.without-goals",
                                                                comment: "header of the 'projects without goals' section of the project list")
            }
        }
        return view
    }


    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else {
            selectedProjectID.value = nil
            return
        }
        selectedProjectID.value = currentProjectIDs.value.projectId(for: indexPath)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        selectedProjectID.value = nil
    }
}
