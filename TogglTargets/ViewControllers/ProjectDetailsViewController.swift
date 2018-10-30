//
//  ProjectDetailsViewController.swift
//  TogglTargets
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

class ProjectDetailsViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        project: SignalProducer<Project, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        calendar: SignalProducer<Calendar, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        readTimeTarget: ReadTimeTarget,
        writeGoal: BindingTarget<TimeTarget>,
        readReport: ReadReport)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Private properties

    /// Selected project.
    private let project = MutableProperty<Project?>(nil)

    private let readTimeTarget = MutableProperty<ReadTimeTarget?>(nil)
    private let readReport = MutableProperty<ReadReport?>(nil)


    // MARK: - Derived input

    private lazy var projectId: SignalProducer<Int64, NoError> = project.producer.skipNil().map { $0.id }

    /// TimeTarget corresponding to the selected project.
    private lazy var goalForCurrentProject: SignalProducer<TimeTarget?, NoError> = projectId
        .throttle(while: readTimeTarget.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readTimeTarget.producer.skipNil())
        .map { projectId, readTimeTarget in readTimeTarget(projectId) }
        .flatten(.latest)


    /// Report corresponding to the selected project.
    private lazy var reportForCurrentProject: SignalProducer<TwoPartTimeReport?, NoError> = projectId
        .throttle(while: readReport.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readReport.producer.skipNil())
        .map { projectId, readTimeTarget in readTimeTarget(projectId) }
        .flatten(.latest) // TODO: generalize and reuse

    // MARK: - Contained view controllers

    private lazy var goalReportViewController: GoalReportViewController = {
        let goalReport = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("GoalReportViewController")) as! GoalReportViewController
        goalReport <~ SignalProducer(
            value: (projectId: projectId,
                    timeTarget: goalForCurrentProject.skipNil(),
                    report: reportForCurrentProject,
                    runningEntry: lastBinding.latestOutput { $0.runningEntry },
                    calendar: lastBinding.latestOutput { $0.calendar },
                    currentDate: lastBinding.latestOutput { $0.currentDate },
                    periodPreference: lastBinding.latestOutput { $0.periodPreference }))
        addChildViewController(goalReport)
        return goalReport
    }()

    private lazy var noGoalViewController: NoGoalViewController = {
        let noGoal = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("NoGoalViewController")) as! NoGoalViewController
        addChildViewController(noGoal)
        return noGoal
    }()

    private func setupConditionalVisibilityOfContainedViews() {
        let selectedGoalController = goalForCurrentProject
            .observe(on: UIScheduler())
            .map { [unowned self] in
            $0 == nil ? self.noGoalViewController : self.goalReportViewController
        }
        goalReportView.uniqueSubview <~ selectedGoalController.map { $0.view }.skipRepeats()
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let goalController = segue.destinationController as? GoalViewController {
            let validBindings = lastBinding.producer.skipNil()
            goalController <~
                SignalProducer.combineLatest(
                    validBindings.map { ($0.calendar, $0.periodPreference, $0.writeGoal) },
                    SignalProducer(value: goalForCurrentProject.producer))
                    .map {
                        (calendar: $0.0,
                         timeTarget: $1,
                         periodPreference: $0.1,
                         userUpdates: $0.2)
            }
        }
    }

    // MARK: - Outlets

    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var goalReportView: NSView!


    //  MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        project <~ lastBinding.latestOutput { $0.project }

        let lastValidBinding = lastBinding.producer.skipNil()
        readTimeTarget <~ lastValidBinding.map { $0.readTimeTarget }
        readReport <~ lastValidBinding.map { $0.readReport }

        setupLocalProjectDisplay()
        setupConditionalVisibilityOfContainedViews()
    }

    private func setupLocalProjectDisplay() {
        project.producer.observe(on: UIScheduler()).startWithValues { [unowned self] projectOrNil in
            self.projectName.stringValue = projectOrNil?.name ?? ""
        }
    }
}
