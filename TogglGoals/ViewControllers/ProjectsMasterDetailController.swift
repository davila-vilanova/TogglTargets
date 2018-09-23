//
//  ProjectsMasterDetailController.swift
//  TogglGoals
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
        projectIDsByGoals: ProjectIDsByGoalsProducer,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>,
        readProject: ReadProject,
        readGoal: ReadGoal,
        writeGoal: BindingTarget<Goal>,
        deleteGoal: BindingTarget<ProjectID>,
        readReport: ReadReport)

    private let lastBinding = MutableProperty<Interface?>(nil)

    internal var bindingTarget: BindingTarget<ProjectsMasterDetailController.Interface?> { return lastBinding.bindingTarget }


    // MARK: - Private

    private let selectedProjectId = MutableProperty<ProjectID?>(nil)

    private lazy var readGoal = Property(initial: nil, then: lastBinding.producer.skipNil().map { $0.readGoal })

    private lazy var isProjectWithGoalCurrentlySelected =
        Property(initial: false, then: SignalProducer.combineLatest(selectedProjectId.producer, readGoal.producer)
            .map { p, r -> SignalProducer<Goal?, NoError> in
                guard let projectId = p,
                    let readGoal = r
                    else {
                        return SignalProducer<Goal?, NoError>(value: nil)
                }
                return readGoal(projectId)
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
                .map { selectedProjectIdTarget, binding in
                    (binding.projectIDsByGoals,
                     selectedProjectIdTarget,
                     binding.runningEntry,
                     binding.currentDate,
                     binding.periodPreference,
                     binding.modelRetrievalStatus,
                     binding.readProject,
                     binding.readGoal,
                     binding.readReport)
        }

        let interceptWriteGoal = MutableProperty<Goal?>(nil)
        reactive.lifetime.observeEnded {
            _ = interceptWriteGoal
        }

        selectionDetailViewController <~
            SignalProducer.combineLatest(SignalProducer(value: selectedProjectId.producer),
                                         lastBinding.producer.skipNil(),
                                         SignalProducer(value: interceptWriteGoal.deoptionalizedBindingTarget))
                .map { selectedProjectIdProducer, binding, writeGoal in
                    (selectedProjectIdProducer,
                     binding.currentDate,
                     binding.calendar,
                     binding.periodPreference,
                     binding.runningEntry,
                     binding.readProject,
                     binding.readGoal,
                     writeGoal,
                     binding.readReport)
        }

        interceptWriteGoal.producer.skipNil()
            .bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.writeGoal })
        reactive.makeBindingTarget { controller, _ in
            controller.undoManager?.setActionName(NSLocalizedString("undo.modify-goal", comment: "undo action name: modify goal"))
            } <~ interceptWriteGoal.producer.skipNil().map { _ in () }
    }

    @IBAction public func createGoal(_ sender: Any?) {
        guard canCreateGoal,
            let projectId = selectedProjectId.value,
            let writeGoal = lastBinding.value?.writeGoal else {
                return
        }
        undoManager?.setActionName(NSLocalizedString("undo.create-goal", comment: "undo action name: create goal"))
        writeGoal <~ SignalProducer(value: Goal.createDefault(for: projectId))
    }

    @IBAction public func deleteGoal(_ sender: Any?) {
        guard canDeleteGoal,
            let projectId = selectedProjectId.value,
            let deleteGoal = lastBinding.value?.deleteGoal else {
                return
        }
        undoManager?.setActionName(NSLocalizedString("undo.delete-goal", comment: "undo action name: delete goal"))
        deleteGoal <~ SignalProducer(value: projectId)
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
        } else if item.action == #selector(deleteGoal(_:)) {
            return canDeleteGoal
        } else {
            return true
        }
    }
}
