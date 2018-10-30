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

class ProjectsMasterDetailController: NSSplitViewController, BindingTargetProvider, GoalCreatingDeleting {

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

    internal var bindingTarget: BindingTarget<ProjectsMasterDetailController.Interface?> { return lastBinding.bindingTarget }


    // MARK: - Private

    private let selectedProjectId = MutableProperty<ProjectID?>(nil)

    private let focusOnUndoProjectId = MutableProperty<ProjectID?>(nil)

    private let createGoal = MutableProperty<TimeTarget?>(nil)

    private let modifyGoal = MutableProperty<TimeTarget?>(nil)

    private let deleteTimeTarget = MutableProperty<ProjectID?>(nil)

    private lazy var registerSelectionInUndoManager: BindingTarget<ProjectID> = reactive.makeBindingTarget { controller, projectId in
        controller.undoManager?.registerUndo(withTarget: controller.focusOnUndoProjectId) {
            $0 <~ SignalProducer(value: projectId) }
    }

    private lazy var setUndoActionName = reactive.makeBindingTarget { controller, actionName in
        controller.undoManager?.setActionName(actionName)
    }

    private lazy var readTimeTarget = Property(initial: nil, then: lastBinding.producer.skipNil().map { $0.readTimeTarget })

    private lazy var isProjectWithGoalCurrentlySelected =
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
        return splitViewItem(.projectsList).viewController as! ProjectsListActivityViewController
    }

    private var selectionDetailViewController: SelectionDetailViewController {
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
                                         SignalProducer(value: modifyGoal.deoptionalizedBindingTarget))
                .map { selectedProjectIdProducer, binding, modifyGoal in
                    (selectedProjectIdProducer,
                     binding.currentDate,
                     binding.calendar,
                     binding.periodPreference,
                     binding.runningEntry,
                     binding.readProject,
                     binding.readTimeTarget,
                     modifyGoal,
                     binding.readReport)
        }

        registerSelectionInUndoManager <~ SignalProducer.merge(createGoal.producer.skipNil().map { $0.projectId },
                                                               modifyGoal.producer.skipNil().map { $0.projectId },
                                                               deleteTimeTarget.producer.skipNil())

        createGoal.producer.skipNil()
            .bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.writeTimeTarget })

        modifyGoal.producer.skipNil()
            .bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.writeTimeTarget })

        deleteTimeTarget.producer.skipNil()
            .bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.deleteTimeTarget })

        setUndoActionName <~ createGoal.producer.skipNil()
            .map { _ in NSLocalizedString("undo.create-time-target", comment: "undo action name: create time target") }
        setUndoActionName <~ modifyGoal.producer.skipNil()
            .map { _ in NSLocalizedString("undo.modify-time-target", comment: "undo action name: modify time target") }
        setUndoActionName <~ deleteTimeTarget.producer.skipNil()
            .map { _ in NSLocalizedString("undo.delete-time-target", comment: "undo action name: delete time target") }


        registerSelectionInUndoManager <~ focusOnUndoProjectId.producer.skipNil()
    }

    @IBAction public func createGoal(_ sender: Any?) {
        guard canCreateGoal,
            let projectId = selectedProjectId.value else {
                return
        }
        createGoal <~ SignalProducer(value: TimeTarget.createDefault(for: projectId))
    }

    @IBAction public func deleteTimeTarget(_ sender: Any?) {
        guard canDeleteGoal,
            let projectId = selectedProjectId.value else {
                return
        }
        deleteTimeTarget <~ SignalProducer(value: projectId)
    }

    private var canCreateGoal: Bool {
        return !isProjectWithGoalCurrentlySelected.value
    }

    private var canDeleteGoal: Bool {
        return isProjectWithGoalCurrentlySelected.value
    }

    public override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(createGoal(_:)) {
            return canCreateGoal
        } else if item.action == #selector(deleteTimeTarget(_:)) {
            return canDeleteGoal
        } else {
            return true
        }
    }
}
