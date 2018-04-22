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

/// Manages a collection view that displays `Project` items organized by whether they have an associated goal.
/// Produces a stream of selected `Project` values via the `selectedProject` property.
class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate {

    // MARK: - Interface

    ///   - projectIDsByGoals: a producer of `ProjectIDsByGoals.Update` values
    ///     that when started emits a `full(ProjectIDsByGoals)` value which can
    ///     be followed by full or incremental updates.
    ///   - selectedProjectId:  Emits `Project` values whenever a project is selected
    ///     or `nil` when no project is selected. Only one project can be selected at a time.
    ///   - runningEntry: A signal producer that emits `RunningEntry` or `nil` values depending on whether
    ///     a time entry is currently active. This is used to add the currently running time to the reported
    ///     worked time for the corresponding project.
    ///   - currentDate: A signal producer that emits `Date` values corresponding to the current date as time passes.
    ///     This is useful to calculate the elapsed running time of the active time entry provided by `runningEntry`.
    ///   - readProject: An `Action` this controller will apply to obtain project `Property` instances
    ///     corresponding to its input project IDs.
    ///   - readGoal: A function this controller will use to read goals corresponding
    ///     to its input project IDs.
    ///   - readReport: A function this controller will use to read `TwoPartTimeReport`s
    ///     corresponding to its input project IDs.
    internal typealias Interface = (
        projectIDsByGoals: ProjectIDsByGoalsProducer,
        selectedProjectId: BindingTarget<ProjectID?>,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        readProject: ReadProject,
        readGoal: ReadGoal,
        readReport: ReadReport)

    private let _interface = MutableProperty<Interface?>(nil)
    internal var interface: BindingTarget<Interface?> { return _interface.bindingTarget }

    private func connectInterface() {
        projectIDsByGoals <~ _interface.latestOutput { $0.projectIDsByGoals }
        runningEntry <~ _interface.latestOutput { $0.runningEntry }
        currentDate <~ _interface.latestOutput { $0.currentDate }

        let ownInterface = _interface.producer.skipNil()
        readProject <~ ownInterface.map { $0.readProject }
        readGoal <~ ownInterface.map { $0.readGoal }
        readReport <~ ownInterface.map { $0.readReport }
        lifetime += selectedProjectID.bindOnlyToLatest(ownInterface.map { $0.selectedProjectId })
    }


    // MARK: - Backing properties

    /// Holds the input `RunningEntry` values.
    private let runningEntry = MutableProperty<RunningEntry?>(nil)

    /// Holds the current `Date` input values.
    private let currentDate = MutableProperty<Date?>(nil)

    /// Holds the ID of the currently selected project, if any.
    private let selectedProjectID = MutableProperty<ProjectID?>(nil)


    /// The function used to read projects by project ID.
    private let readProject = MutableProperty<ReadProject?>(nil)

    /// The function used to read goals by project ID.
    private let readGoal = MutableProperty<ReadGoal?>(nil)

    /// The action used to read reports by project ID.
    private let readReport = MutableProperty<ReadReport?>(nil)


    // MARK: - Outlets

    /// The collection view in charge of displaying the projects organized by goals following the
    /// project ID order and the structure of the current `ProjectIDsByGoals` value.
    @IBOutlet weak var projectsCollectionView: NSCollectionView!


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeProjectsCollectionView()
        connectInterface()
    }

    private func initializeProjectsCollectionView() {
        let itemNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewItem"), bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: ProjectItemIdentifier)

        let headerNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewHeader"), bundle: nil)!
        projectsCollectionView.register(headerNib,
                                        forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader,
                                        withIdentifier: SectionHeaderIdentifier)
    }

    /// The lifetime (and lifetime token) associated to this instance's binding targets.
    private let (lifetime, token) = Lifetime.make()

    /// Accepts full values and incremental udpates of the `ProjectIDsByGoals` value that is used to
    /// determine the order and organization of the displayed projects.
    /// Full values cause a full refresh. Incremental updates cause a reorder of projects in the
    /// displayed collection.
    /// Expects a full value first.
    internal lazy var projectIDsByGoals =
        BindingTarget<ProjectIDsByGoals.Update>(on: UIScheduler(), lifetime: lifetime) { [unowned self] update in
            switch update {
            case .full(let projectIDs):
                self.refresh(with: projectIDs)
            case .singleGoal(let goalUpdate):
                self.update(with: goalUpdate)
            }
    }

    /// The current value of `ProjectsIDsByGoals`.
    private var currentProjectIDs = ProjectIDsByGoals.empty

    /// Sets the current value of `currentProjectIDs` and triggers a full refresh of the collection
    /// view that will reflect the provided value.
    private func refresh(with projectIDs: ProjectIDsByGoals) {
        self.currentProjectIDs = projectIDs
        self.projectsCollectionView.reloadData()
        self.sendSelectedProjectValue()
        self.scrollToSelection()
    }

    /// Reflects the provided update in the value of `currentProjectIDs` and reorders the affected item
    /// in the collection view.
    private func update(with update: ProjectIDsByGoals.Update.GoalUpdate) {
        let beforeMove = self.currentProjectIDs
        let afterMove = update.apply(to: beforeMove)
        let oldIndexPath = beforeMove.indexPath(forElementAt: update.indexChange.old)!
        let newIndexPath = afterMove.indexPath(forElementAt: update.indexChange.new)!

        self.currentProjectIDs = afterMove
        self.projectsCollectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
        self.scrollToSelection()
    }

    /// Sends the value of the selected project through the `selectedProject` output.
    private func sendSelectedProjectValue() {
        if let indexPath = projectsCollectionView.selectionIndexPaths.first,
            let projectID = currentProjectIDs.projectId(for: indexPath) {
            selectedProjectID.value = projectID
        } else {
            selectedProjectID.value = nil
        }
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
        projectItem.connectOnceInLifecycle(runningEntry: runningEntry.producer,
                                           currentDate: currentDate.producer.skipNil())

        let projectId: ProjectID = currentProjectIDs.projectId(for: indexPath)!

        // TODO: De-force-unwrap
        projectItem.setInputs(project: readProject.value!(projectId),
                              goal: readGoal.value!(projectId),
                              report: readReport.value!(projectId))

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
        sendSelectedProjectValue()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        sendSelectedProjectValue()
    }
}
