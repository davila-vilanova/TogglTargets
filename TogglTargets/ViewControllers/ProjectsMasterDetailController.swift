//
//  ProjectsMasterDetailController.swift
//  TogglTargets
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

class ProjectsMasterDetailController: NSSplitViewController, BindingTargetProvider, TimeTargetCreatingDeleting {

    // MARK: - Interface

    internal typealias Interface = (
        calendar: SignalProducer<Calendar, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        projectIDsByTimeTargets: ProjectIDsByTimeTargetsProducer,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>,
        readProject: ReadProject,
        readTimeTarget: ReadTimeTarget,
        writeTimeTarget: BindingTarget<TimeTarget>,
        deleteTimeTarget: BindingTarget<ProjectID>,
        readReport: ReadReport)

    private let lastBinding = MutableProperty<Interface?>(nil)

    internal var bindingTarget: BindingTarget<ProjectsMasterDetailController.Interface?> {
        return lastBinding.bindingTarget
    }

    // MARK: - Private

    private let selectedProjectId = MutableProperty<ProjectID?>(nil)

    private lazy var selectedProject: Property<Project?> = {
        func isNil(_ val: Any?) -> Bool {
            return val == nil
        }
        func toVoid(_ val: Any) {
            return ()
        }
        let projectIdPlusReadProject =
            SignalProducer.combineLatest(selectedProjectId.producer.skipNil(),
                                         lastBinding.producer.skipNil().map { $0.readProject })
        let missingProjectIdOrReadProject =
            SignalProducer.combineLatest(selectedProjectId.producer.filter(isNil),
                                         lastBinding.producer.filter(isNil)).map(toVoid)
        let projects = projectIdPlusReadProject.map { $0.1($0.0) }.flatten(.latest)
        let missingProjects = projects.filter(isNil).map(toVoid)
        let nilValues = SignalProducer.merge(missingProjectIdOrReadProject, missingProjects).map { nil as Project? }
        let projectValues = SignalProducer.merge(projects.skipNil().map { $0 as Project? }, nilValues)
        return Property(initial: nil, then: projectValues)
    }()

    private let focusOnUndoProjectId = MutableProperty<ProjectID?>(nil)

    private let createTimeTarget = MutableProperty<TimeTarget?>(nil)

    private let modifyTimeTarget = MutableProperty<TimeTarget?>(nil)

    private let deleteTimeTarget = MutableProperty<ProjectID?>(nil)

    private lazy var registerSelectionInUndoManager: BindingTarget<ProjectID> =
        reactive.makeBindingTarget { controller, projectId in
            controller.undoManager?.registerUndo(withTarget: controller.focusOnUndoProjectId) {
                $0 <~ SignalProducer(value: projectId) }
    }

    private lazy var setUndoActionName = reactive.makeBindingTarget { controller, actionName in
        controller.undoManager?.setActionName(actionName)
    }

    private lazy var readTimeTarget =
        Property(initial: nil, then: lastBinding.producer.skipNil().map { $0.readTimeTarget })

    private lazy var isProjectWithTimeTargetCurrentlySelected =
        Property(initial: false, then: SignalProducer.combineLatest(selectedProjectId.producer, readTimeTarget.producer)
            .map { p, r -> SignalProducer<TimeTarget?, NoError> in
                guard let projectId = p,
                    let readTimeTarget = r
                    else {
                        return SignalProducer<TimeTarget?, NoError>(value: nil)
                }
                return readTimeTarget(projectId)
            }
            .flatten(.latest)
            .map { $0 != nil }
    )

    // MARK: - Contained view controllers

    /// Represents the two split items this controller contains
    private enum SplitItemIndex: Int {
        case projectsList = 0
        case selectionDetail
    }

    private var projectsListActivityViewController: ProjectsListActivityViewController {
        // swiftlint:disable:next force_cast
        return splitViewItem(.projectsList).viewController as! ProjectsListActivityViewController
    }

    private var selectionDetailViewController: SelectionDetailViewController {
        // swiftlint:disable:next force_cast
        return splitViewItem(.selectionDetail).viewController as! SelectionDetailViewController
    }

    private func splitViewItem(_ index: SplitItemIndex) -> NSSplitViewItem {
        return splitViewItems[index.rawValue]
    }

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        projectsListActivityViewController <~
            SignalProducer.combineLatest(SignalProducer(value: selectedProjectId.bindingTarget),
                                         lastBinding.producer.skipNil())
                .map { [unowned focusOnUndoProjectId] selectedProjectIdTarget, binding in
                    (binding.projectIDsByTimeTargets,
                     selectedProjectIdTarget,
                     focusOnUndoProjectId.producer.skip(first: 1),
                     binding.runningEntry,
                     binding.currentDate,
                     binding.periodPreference,
                     binding.modelRetrievalStatus,
                     binding.readProject,
                     binding.readTimeTarget,
                     binding.readReport)
        }

        selectionDetailViewController <~
            SignalProducer.combineLatest(SignalProducer(value: selectedProjectId.producer),
                                         lastBinding.producer.skipNil(),
                                         SignalProducer(value: modifyTimeTarget.deoptionalizedBindingTarget))
                .map { selectedProjectIdProducer, binding, modifyTimeTarget in
                    (selectedProjectIdProducer,
                     binding.currentDate,
                     binding.calendar,
                     binding.periodPreference,
                     binding.runningEntry,
                     binding.readProject,
                     binding.readTimeTarget,
                     modifyTimeTarget,
                     binding.readReport)
        }

        deleteTimeTarget <~ showConfirmDeleteSheet.values.filterMap { $0.projectIdToDelete }

        reactive.lifetime += showConfirmDeleteSheet.disabledErrors.observeValues {
            print("Cannot show 'confirm delete' sheet - action is disabled")
        }

        registerSelectionInUndoManager <~ SignalProducer.merge(createTimeTarget.producer.skipNil().map { $0.projectId },
                                                               modifyTimeTarget.producer.skipNil().map { $0.projectId },
                                                               deleteTimeTarget.producer.skipNil())

        createTimeTarget.producer.skipNil()
            .bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.writeTimeTarget })

        modifyTimeTarget.producer.skipNil()
            .bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.writeTimeTarget })

        deleteTimeTarget.producer.skipNil()
            .bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.deleteTimeTarget })

        setUndoActionName <~ createTimeTarget.producer.skipNil()
            .map { _ in NSLocalizedString("undo.create-time-target", comment: "undo action name: create time target") }
        setUndoActionName <~ modifyTimeTarget.producer.skipNil()
            .map { _ in NSLocalizedString("undo.modify-time-target", comment: "undo action name: modify time target") }
        setUndoActionName <~ deleteTimeTarget.producer.skipNil()
            .map { _ in NSLocalizedString("undo.delete-time-target", comment: "undo action name: delete time target") }

        registerSelectionInUndoManager <~ focusOnUndoProjectId.producer.skipNil()
    }

    @IBAction public func createTimeTarget(_ sender: Any?) {
        guard canCreateTimeTarget,
            let projectId = selectedProjectId.value else {
                return
        }
        createTimeTarget <~ SignalProducer(value: TimeTarget.createDefault(for: projectId))
    }

    @IBAction public func deleteTimeTarget(_ sender: Any?) {
        showConfirmDeleteSheet <~ SignalProducer(value: ())
    }

    private var canCreateTimeTarget: Bool {
        return !isProjectWithTimeTargetCurrentlySelected.value
    }

    private var canDeleteTimeTarget: Bool {
        return isProjectWithTimeTargetCurrentlySelected.value
    }

    public override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(createTimeTarget(_:)) {
            return canCreateTimeTarget
        } else if item.action == #selector(deleteTimeTarget(_:)) {
            return canDeleteTimeTarget
        } else {
            return true
        }
    }

    // MARK: - Confirm delete
    private enum ConfirmDeleteResolution {
        case delete(projectId: ProjectID)
        case doNotDelete
        var projectIdToDelete: ProjectID? {
            switch self {
            case .delete(let projectId): return projectId
            default: return nil
            }
        }
    }

    private lazy var showConfirmDeleteSheet =
        Action<Void, ConfirmDeleteResolution, NoError>(state:
            selectedProject.combineLatest(with: isProjectWithTimeTargetCurrentlySelected),
                                                       enabledIf: { $0.0 != nil && $0.1 }) { [unowned self] state, _ in
            guard let window = self.view.window else {
                return SignalProducer.empty
            }

            let project = state.0!

            return SignalProducer { (observer: Signal<ConfirmDeleteResolution, NoError>.Observer, _: Lifetime) in
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = String.localizedStringWithFormat(
                    NSLocalizedString("confirm-delete.title", comment: "title of 'confirm delete' alert sheet"),
                    project.name ?? "")
                alert.informativeText = NSLocalizedString("confirm-delete.informative",
                                                          comment: "informative text in 'confirm delete' alert sheet")

                alert.addButton(withTitle:
                    NSLocalizedString("confirm-delete.do-delete",
                                      comment: "title of 'confirm delete' button in 'confirm delete' alert sheet"))
                alert.addButton(withTitle:
                    NSLocalizedString("confirm-delete.do-not-delete",
                                      comment: "title of 'don't delete' button in 'confirm delete' alert sheet"))

                alert.beginSheetModal(for: window) { response in
                    switch response {
                    case .alertFirstButtonReturn: observer.send(value: .delete(projectId: project.id))
                    case .alertSecondButtonReturn: fallthrough
                    default: observer.send(value: .doNotDelete)
                    }
                    observer.sendCompleted()
                }
            }
    }
}
