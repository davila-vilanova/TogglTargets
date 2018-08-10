//
//  SelectionDetailViewController.swift
//  TogglGoals
//
//  Created by David Davila on 03.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

fileprivate let ProjectDetailsVCContainment = "ProjectDetailsVCContainment"
fileprivate let EmtpySelectionVCContainment = "EmtpySelectionVCContainment"

class SelectionDetailViewController: NSTabViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface =
        (projectId: SignalProducer<ProjectID?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        calendar: SignalProducer<Calendar, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        readProject: ReadProject,
        readGoal: ReadGoal,
        writeGoal: BindingTarget<Goal>,
        deleteGoal: BindingTarget<ProjectID>,
        readReport: ReadReport)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Local use of project

    private let readProject = MutableProperty<((ProjectID) -> SignalProducer<Project?, NoError>)?>(nil)
    private let selectedProjectID = MutableProperty<ProjectID?>(nil)
    private lazy var selectedProject: SignalProducer<Project?, NoError> = selectedProjectID.producer
        .throttle(while: readProject.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readProject.producer.skipNil())
        .map { projectID, readProject -> SignalProducer<Project?, NoError> in
            if let projectID = projectID {
                return readProject(projectID)
            } else {
                return SignalProducer(value: nil)
            }
        }
        .flatten(.latest)


    // MARK: - Contained view controllers

    private enum ContainedControllerType: Int {
        case projectDetails = 1
        case emptySelection = 0

        static func from(_ controller: NSViewController) -> ContainedControllerType? {
            if controller as? ProjectDetailsViewController != nil {
                return .projectDetails
            } else if controller as? EmptySelectionViewController != nil {
                return .emptySelection
            } else {
                return nil
            }
        }
    }

    private var connectedControllerTypes = Set<ContainedControllerType>()

    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)

        guard let controller = tabViewItem?.viewController,
        let type = ContainedControllerType.from(controller),
        !connectedControllerTypes.contains(type) else {
            return
        }

        connectedControllerTypes.insert(type)

        if let details = controller as? ProjectDetailsViewController {
            details <~ SignalProducer.combineLatest(SignalProducer(value: selectedProject.skipNil()),
                                                    lastBinding.producer.skipNil())
                .map {
                    selectedProjectProducer, binding in
                    (selectedProjectProducer,
                     binding.currentDate,
                     binding.calendar,
                     binding.periodPreference,
                     binding.runningEntry,
                     binding.readGoal,
                     binding.writeGoal,
                     binding.deleteGoal,
                     binding.readReport)
            }
        }
    }


    // MARK: -

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        selectedProjectID <~ lastBinding.latestOutput { $0.projectId }
        readProject <~ lastBinding.producer.skipNil().map { $0.readProject }

        let debounceScheduler = QueueScheduler()
        lifetime.observeEnded {
            _ = debounceScheduler
        }

        reactive.makeBindingTarget { $0.selectedTabViewItemIndex = $1 } <~ selectedProjectID
            .map { ($0 != nil) ? ContainedControllerType.projectDetails.rawValue : ContainedControllerType.emptySelection.rawValue }
            .producer.debounce(0.1, on: debounceScheduler)
    }
}
