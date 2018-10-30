//
//  SelectionDetailViewController.swift
//  TogglTargets
//
//  Created by David Davila on 03.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

fileprivate let ProjectDetailsVCContainment = "ProjectDetailsVCContainment"
fileprivate let EmtpySelectionVCContainment = "EmtpySelectionVCContainment"

class SelectionDetailViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface =
        (projectId: SignalProducer<ProjectID?, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        calendar: SignalProducer<Calendar, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        readProject: ReadProject,
        readGoal: ReadTimeTarget,
        writeGoal: BindingTarget<TimeTarget>,
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

    private lazy var projectDetailsViewController: ProjectDetailsViewController = {
        let details = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ProjectDetailsViewController")) as! ProjectDetailsViewController

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
                 binding.readReport)
        }

        addChildViewController(details)

        return details
    }()

    private lazy var emptySelectionViewController: EmptySelectionViewController = {
        let empty = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("EmptySelectionViewController")) as! EmptySelectionViewController
        addChildViewController(empty)
        return empty
    }()

    @IBOutlet weak var containerView: NSView!

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        selectedProjectID <~ lastBinding.latestOutput { $0.projectId }
        readProject <~ lastBinding.producer.skipNil().map { $0.readProject }

        let debounceScheduler = QueueScheduler()
        reactive.lifetime.observeEnded {
            _ = debounceScheduler
        }

        let selectedViewController = selectedProjectID
            .producer
            .map { $0 != nil }
            .skipRepeats()
            .debounce(0.1, on: debounceScheduler)
            .observe(on: UIScheduler())
            .map { [unowned self] projectSelected in projectSelected ? self.projectDetailsViewController : self.emptySelectionViewController }

        containerView.uniqueSubview <~ selectedViewController.map { $0.view }
    }
}
