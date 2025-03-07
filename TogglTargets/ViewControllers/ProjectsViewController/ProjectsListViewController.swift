//
//  ProjectsListViewController.swift
//  TogglTargets
//
//  Created by David Davila on 21/10/2016.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import ReactiveSwift

private let projectItemIdentifier = NSUserInterfaceItemIdentifier("ProjectItemIdentifier")
private let sectionHeaderIdentifier = NSUserInterfaceItemIdentifier("SectionHeaderIdentifier")

private let headerHeight: CGFloat = 30
private let projectItemHeight: CGFloat = 62

private let selectedProjectIdRestorationKey = "SelectedProjectId"
private let noSelectedProjectIdRestorationValue: Int64 = 0

/// Manages a collection view that displays `Project` items organized by whether they have an associated time target.
/// Produces a stream of selected `Project` values via the `selectedProject` property.
class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate,
    BindingTargetProvider, OnboardingTargetViewsProvider { // swiftlint:disable:previous type_body_length

    // MARK: - Interface

    internal typealias Interface = (
        projectIDsByTimeTargets: ProjectIDsByTimeTargetsProducer,
        selectionUpstream: BindingTarget<ProjectID?>,
        selectionDownstream: SignalProducer<ProjectID?, Never>,
        runningEntry: SignalProducer<RunningEntry?, Never>,
        currentDate: SignalProducer<Date, Never>,
        periodPreference: SignalProducer<PeriodPreference, Never>,
        readProject: ReadProject,
        readTimeTarget: ReadTimeTarget,
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

    /// The function used to read time targets by project ID.
    private let readTimeTarget = MutableProperty<ReadTimeTarget?>(nil)

    /// The action used to read reports by project ID.
    private let readReport = MutableProperty<ReadReport?>(nil)

    // MARK: - Private properties

    /// The current value of `ProjectsIDsByTimeTargets`.
    private var currentProjectIDs = MutableProperty(ProjectIDsByTimeTargets.empty)

    private var lastProjectIDsByTimeTargetsUpdate = MutableProperty<ProjectIDsByTimeTargets.Update?>(nil)

    // MARK: - Outlets

    /// The collection view in charge of displaying the projects organized by time targets following the
    /// project ID order and the structure of the current `ProjectIDsByTimeTargets` value.
    @IBOutlet weak var projectsCollectionView: NSCollectionView!

    @IBOutlet weak var clipView: NSClipView!

    // MARK: - State restoration

    private let restoredSelectedProjectId = MutableProperty<ProjectID?>(nil)

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode((selectedProjectID.value ?? noSelectedProjectIdRestorationValue) as Int64,
                     forKey: selectedProjectIdRestorationKey)
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        let restoredSelectedProjectId = coder.decodeInt64(forKey: selectedProjectIdRestorationKey)
        self.restoredSelectedProjectId.value = restoredSelectedProjectId == noSelectedProjectIdRestorationValue ?
            nil : restoredSelectedProjectId
    }

    private func invalidateRestorableStateWhenProjectManuallySelected() {
        reactive.makeBindingTarget { controller, _ in
            controller.invalidateRestorableState()
            } <~ selectedProjectID
    }

    private func restoreSelectionInCollectionView() {
        let projectManuallySelected = selectedProjectID.signal.map { _ in () }

        let selectIndexPath = reactive.makeBindingTarget { controller, indexPath in
            controller.projectsCollectionView.selectItems(at: [indexPath], scrollPosition: .nearestHorizontalEdge)
        }

        let indexPathFromPersistedProjectId = SignalProducer.combineLatest(currentProjectIDs, restoredSelectedProjectId)
            .take(until: projectManuallySelected)
            .compactMap { (currentProjectIds, restoredProjectId) -> IndexPath? in
                guard let projectId = restoredProjectId else {
                    return nil
                }
                return currentProjectIds.indexPath(for: projectId)
            }
            .take(first: 1)

        reactive.lifetime += selectIndexPath <~ indexPathFromPersistedProjectId
    }

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackgroundOfAreasExposedByScrollElasticity()

        initializeProjectsCollectionView()
        wireFullUpdatesToCollectionView()
        wireSingleTimeTargetUpdatesToCollectionView()

        // Connect interface to private properties
        lastProjectIDsByTimeTargetsUpdate <~ lastBinding.latestOutput { $0.projectIDsByTimeTargets }
        runningEntry <~ lastBinding.latestOutput { $0.runningEntry }
        currentDate <~ lastBinding.latestOutput { $0.currentDate }
        periodPreference <~ lastBinding.latestOutput { $0.periodPreference }

        let lastValidBinding = lastBinding.producer.skipNil()
        readProject <~ lastValidBinding.map { $0.readProject }
        readTimeTarget <~ lastValidBinding.map { $0.readTimeTarget }
        readReport <~ lastValidBinding.map { $0.readReport }

        let selectedProjectId = restoredSelectedProjectId.producer
            .take(untilReplacement: SignalProducer.merge(self.selectedProjectID.producer.skip(first: 1),
                                                         lastBinding.latestOutput { $0.selectionDownstream }))
        reactive.lifetime += selectedProjectId.bindOnlyToLatest(lastValidBinding.map { $0.selectionUpstream })

        invalidateRestorableStateWhenProjectManuallySelected()
        restoreSelectionInCollectionView()
        wireDownstreamSelection()
    }

    private func setupBackgroundOfAreasExposedByScrollElasticity() {
        let attachedLength: CGFloat = 1000

        func attachBackgroundView(_ createAdjacentConstraint: (NSView, NSClipView) -> NSLayoutConstraint ) -> NSView {
            let backgroundView = NSView(frame: NSRect.zero)
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            clipView.addSubview(backgroundView)

            backgroundView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor).isActive = true
            backgroundView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor).isActive = true
            backgroundView.heightAnchor.constraint(equalToConstant: attachedLength).isActive = true
            createAdjacentConstraint(backgroundView, clipView).isActive = true

            backgroundView.wantsLayer = true
            return backgroundView
        }

        let backgroundViews = [
            attachBackgroundView { background, clip in
                background.bottomAnchor.constraint(equalTo: clip.documentView!.topAnchor)
            },
            attachBackgroundView { background, clip in
                background.topAnchor.constraint(equalTo: clip.documentView!.bottomAnchor)
            }
        ]

        for background in backgroundViews {
            let updateColor: BindingTarget<Void> = background.reactive.makeBindingTarget { view, _ in
                view.layer!.backgroundColor = NSColor.underPageBackgroundColor.cgColor
            }
            updateColor <~ clipView.reactive.trigger(for: #selector(NSView.layout))
        }
    }

    private func initializeProjectsCollectionView() {
        let itemNib = NSNib(nibNamed: "ProjectCollectionViewItem", bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: projectItemIdentifier)

        let headerNib = NSNib(nibNamed: "ProjectCollectionViewHeader", bundle: nil)!
        projectsCollectionView.register(headerNib,
                                        forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
                                        withIdentifier: sectionHeaderIdentifier)

        // swiftlint:disable:next force_cast
        let layout = projectsCollectionView.collectionViewLayout as! VerticalListLayout
        layout.headerReferenceSize = CGSize(width: projectsCollectionView.bounds.width, height: headerHeight)
        layout.sectionHeadersPinToVisibleBounds = true
        layout.minimumLineSpacing = 0 // avoid gap between items
        layout.itemHeight = projectItemHeight
    }

    func wireFullUpdatesToCollectionView() {
        // set the current value of `currentProjectIDs` and trigger a full refresh of the collection view
        let fullUpdates = lastProjectIDsByTimeTargetsUpdate.producer.skipNil().compactMap { $0.fullyUpdated }

        currentProjectIDs <~ fullUpdates

        reactive.makeBindingTarget { controller, _ in
            controller.projectsCollectionView.reloadData()
            controller.scrollToSelection()
            } <~ fullUpdates.map { _ in () }
    }

    func wireSingleTimeTargetUpdatesToCollectionView () {
        // reflect the provided update in the value of `currentProjectIDs`, reorder the affected item in the
        // collection view and update the "last item in section" visual state
        let singlePidsUpdates =
        lastProjectIDsByTimeTargetsUpdate.signal.skipNil().compactMap { $0.timeTargetUpdate }
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
            .map { (newIndexPath, updatedPids) -> [IndexPath: Bool] in
                var possiblyAffectedItems: Set<IndexPath> =
                    [newIndexPath,
                     updatedPids.indexPathOfLastItem(in: ProjectIDsByTimeTargets.Section.withTimeTargets),
                     updatedPids.indexPathOfLastItem(in: ProjectIDsByTimeTargets.Section.withoutTimeTargets)]

                if let section = ProjectIDsByTimeTargets.Section.init(rawValue: newIndexPath.section),
                    newIndexPath == updatedPids.indexPathOfLastItem(in: section),
                    newIndexPath.item > 0 {
                    possiblyAffectedItems.insert(IndexPath(item: newIndexPath.item - 1, section: newIndexPath.section))
                }

                var withValues = [IndexPath: Bool]()
                for indexPath in possiblyAffectedItems {
                    withValues[indexPath] = updatedPids.isIndexPathOfLastItemInSection(indexPath)
                }
                return withValues
        }

        // update values
        currentProjectIDs <~ updatedPids

        // move items in the collection view according to the latest single-TimeTarget update
        let moveItemsInCollectionView: BindingTarget<(IndexPath, IndexPath)> =
            projectsCollectionView.reactive.makeBindingTarget { collectionView, indexPaths in
                let (oldIndexPath, newIndexPath) = indexPaths
                collectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
        }

        // update "last in section" visual state
        let updateLastItemInSectionState: BindingTarget<[IndexPath: Bool]> =
            projectsCollectionView.reactive.makeBindingTarget { collectionView, itemsToUpdate in
                for (indexPath, isLastInSection) in itemsToUpdate {
                    if let item = collectionView.item(at: indexPath) as? ProjectCollectionViewItem {
                        // will only determine the status of already cached items
                        item.isLastItemInSection = isLastInSection
                    }
                }
        }

        moveItemsInCollectionView <~ indexPathUpdates
        updateLastItemInSectionState <~ itemsWhoseLastInSectionStatusMustUpdate
    }

    private func wireDownstreamSelection() {
        let selectInCollectionView: BindingTarget<IndexPath> = projectsCollectionView.reactive.makeBindingTarget {
            $0.deselectItems(at: $0.selectionIndexPaths)
            $0.selectItems(at: [$1], scrollPosition: .nearestHorizontalEdge)
        }

        let delayScheduler = QueueScheduler()
        selectInCollectionView <~ lastBinding.latestOutput { $0.selectionDownstream }
            .withLatest(from: currentProjectIDs).map { (projectId, idsByTimeTargets) -> IndexPath? in
            guard let projectId = projectId else {
                return nil
            }
            return idsByTimeTargets.indexPath(for: projectId)
            }
            .skipNil()
            // ensure selection will happen last when it's combined with a partial collection update
            .delay(0, on: delayScheduler)
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
        return ProjectIDsByTimeTargets.Section.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        numberOfItemsInSection rawSection: Int) -> Int {
        guard let section = ProjectIDsByTimeTargets.Section(rawValue: rawSection) else {
            return 0
        }
        return currentProjectIDs.value.numberOfItems(in: section)
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: projectItemIdentifier, for: indexPath)
        // swiftlint:disable:next force_cast
        let projectItem = item as! ProjectCollectionViewItem

        let projectId: ProjectID = currentProjectIDs.value.projectId(for: indexPath)!

        projectItem <~ SignalProducer<ProjectCollectionViewItem.Interface, Never>(
            value: (runningEntry.producer,
                    currentDate.producer.skipNil(),
                    readProject.value!(projectId),
                    readTimeTarget.value!(projectId),
                    periodPreference.producer.skipNil(),
                    readReport.value!(projectId)))

        projectItem.isLastItemInSection = currentProjectIDs.value.isIndexPathOfLastItemInSection(indexPath)

        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader,
                                                        withIdentifier: sectionHeaderIdentifier, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            switch ProjectIDsByTimeTargets.Section(rawValue: indexPath.section)! {
            case .withTimeTargets: header.title =
                NSLocalizedString("project-list.header.with-time-targets",
                                  comment: "header of the 'projects with time targets' section of the project list")
            case .withoutTimeTargets: header.title =
                NSLocalizedString("project-list.header.without-time-targets",
                                  comment: "header of the 'projects without time targets' section of the project list")
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

    // MARK: - Onboarding

    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, Never>] {
        let projectWithoutTimeTargetSelected = SignalProducer.combineLatest(
            currentProjectIDs.producer,
            selectedProjectID.producer.skip(first: 1).skipNil())
            .filter { $0.0.indexPath(for: $0.1)?.section ==
                ProjectIDsByTimeTargets.Section.withoutTimeTargets.rawValue }
            .map { _ in () }

        let projectsListView = viewDidLoadProducer
            .map { [unowned self] _ in self.projectsCollectionView as NSView }
            .concat(SignalProducer.never)
            .take(until: projectWithoutTimeTargetSelected)
        return [.selectProject: projectsListView]
    }
} // swiftlint:disable:this file_length
