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

class SelectionDetailViewController: NSViewController, ViewControllerContaining, BindingTargetProvider {

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


    private func setupContainedViewControllerVisibility() {
        let selectedController = selectedProject.producer
            .map { [unowned self] in
                $0 == nil ? self.emptySelectionViewController : self.projectDetailsViewController
            }
        let debounceScheduler = QueueScheduler()
        lifetime.observeEnded {
            _ = debounceScheduler
        }
        setupContainment(of: selectedController.debounce(0.1, on: debounceScheduler), in: self, view: self.view)
    }


    // MARK: - Contained view controllers

    var projectDetailsViewController: ProjectDetailsViewController!

    var emptySelectionViewController: EmptySelectionViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller {
        case _ where (controller as? ProjectDetailsViewController) != nil:
            projectDetailsViewController = controller as! ProjectDetailsViewController
        case _ where (controller as? EmptySelectionViewController) != nil:
            emptySelectionViewController = controller as! EmptySelectionViewController
        default: break
        }
    }


    // MARK: -

    private let (lifetime, token) = Lifetime.make()

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [ProjectDetailsVCContainment, EmtpySelectionVCContainment])

        selectedProjectID <~ lastBinding.latestOutput { $0.projectId }
        readProject <~ lastBinding.producer.skipNil().map { $0.readProject }

        projectDetailsViewController <~
            SignalProducer.combineLatest(SignalProducer(value: selectedProject.skipNil()),
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

        setupContainedViewControllerVisibility()
    }
}
