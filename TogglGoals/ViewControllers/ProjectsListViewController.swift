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

    /// Sets the actions used by this controller.
    ///
    /// - parameters:
    ///   - readProject: An `Action` this controller will apply to obtain project `Property` instances
    ///     corresponding to its input project IDs.
    ///   - readGoal: An `Action` this controller will apply to obtain goal `Property` instances corresponding
    ///     to its input project IDs.
    ///   - readReport: An `Action` this controller will apply to obtain `TwoPartTimeReport` `Property`
    ///     instances corresponding to its input project IDs.
    ///
    /// - note: This method must be called exactly once during the life of this instance.
    internal func setActions(readProject: ReadProjectAction,
                             readGoal: ReadGoalAction,
                             readReport: ReadReportAction) {
        UIScheduler().schedule { [weak self] in
            guard let controller = self else {
                return
            }
            assert(controller.readProjectAction == nil,
                   "ProjectsListViewController's actions must be set exactly once.")
            controller.readProjectAction = readProject
            controller.readGoalAction = readGoal
            controller.readReportAction = readReport
        }
    }

    /// Connects the provided signal producers to the this controller's reactive inputs.
    ///
    /// - parameters:
    ///   - projectIDsByGoals: a producer of `ProjectIDsByGoals.Update` values
    ///     that when started emits a `full(ProjectIDsByGoals)` value which can
    ///     be followed by full or incremental updates.
    ///   - runningEntry: A signal producer that emits `RunningEntry` or `nil` values depending on whether
    ///     a time entry is currently active. This is used to add the currently running time to the reported
    ///     worked time for the corresponding project.
    ///   - currentDate: A signal producer that emits `Date` values corresponding to the current date as time passes.
    ///     This is useful to calculate the elapsed running time of the active time entry provided by `runningEntry`.
    ///
    /// - note: This method must be called exactly once during the life of this instance.
    internal func connectInputs(projectIDsByGoals: ProjectIDsByGoalsProducer,
                                runningEntry: SignalProducer<RunningEntry?, NoError>,
                                currentDate: SignalProducer<Date, NoError>) {
        enforceOnce(for: "ProjectsListViewController") {
            self.runningEntry <~ runningEntry
            self.currentDate <~ currentDate

            self.isReadyToDisplayCollection.firstTrue.startWithValues {
                self.projectIDsByGoals <~ projectIDsByGoals
            }
        }
    }


    // MARK: - Exposed reactive output

    /// Emits `Project` values whenever a project is selected or `nil` when no project is selected.
    /// Only one project can be selected at a time.
    internal lazy var selectedProject = Property<Project?>(_selectedProject)

    
    // MARK: - Backing properties

    /// Holds the input `RunningEntry` values.
    private let runningEntry = MutableProperty<RunningEntry?>(nil)

    /// Holds the current `Date` input values.
    private let currentDate = MutableProperty<Date?>(nil)

    /// Conveys the selected project to the `selectedProject` property.
    private let _selectedProject = MutableProperty<Project?>(nil)


    // MARK: - Actions

    /// The action used to read projects by project ID.
    private var readProjectAction: ReadProjectAction!

    /// The action used to read goals by project ID.
    private var readGoalAction: ReadGoalAction!

    /// The action used to read reports by project ID.
    private var readReportAction: ReadReportAction!


    // MARK: - Outlets

    /// The collection view in charge of displaying the projects organized by goals following the
    /// project ID order and the structure of the current `ProjectIDsByGoals` value.
    @IBOutlet weak var projectsCollectionView: NSCollectionView!


    // MARK: -

    /// Holds a `false` value that changes to `true` when the view is loaded and `projectsCollectionView` is
    /// set up and ready to go.
    private let isReadyToDisplayCollection = MutableProperty(false)

    override func viewDidLoad() {
        super.viewDidLoad()

        let itemNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewItem"), bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: ProjectItemIdentifier)

        let headerNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewHeader"), bundle: nil)!
        projectsCollectionView.register(headerNib,
                                        forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader,
                                        withIdentifier: SectionHeaderIdentifier)
        isReadyToDisplayCollection.value = true
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
        _selectedProject <~ { () -> SignalProducer<Project?, NoError> in
            guard let indexPath = projectsCollectionView.selectionIndexPaths.first,
                let projectId = currentProjectIDs.projectId(for: indexPath) else {
                    return SignalProducer(value: nil)
            }
            return readProjectAction.applySerially(projectId).flatten(.latest)
        }()
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
        sendSelectedProjectValue()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        sendSelectedProjectValue()
    }
}
