//
//  ProjectDetailsViewController.swift
//  TogglGoals
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
        readGoal: ReadGoal,
        writeGoal: BindingTarget<Goal>,
        deleteGoal: BindingTarget<ProjectID>,
        readReport: ReadReport)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    private var (lifetime, token) = Lifetime.make()


    // MARK: - Private properties

    /// Selected project.
    private let project = MutableProperty<Project?>(nil)

    private let readGoal = MutableProperty<ReadGoal?>(nil)
    private let readReport = MutableProperty<ReadReport?>(nil)

    private let updateDeleteGoal = MutableProperty<Goal?>(nil)


    // MARK: - Derived input

    private lazy var projectId: SignalProducer<Int64, NoError> = project.producer.skipNil().map { $0.id }

    /// Goal corresponding to the selected project.
    private lazy var goalForCurrentProject: SignalProducer<Goal?, NoError> = projectId
        .throttle(while: readGoal.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readGoal.producer.skipNil())
        .map { projectId, readGoal in readGoal(projectId) }
        .flatten(.latest)


    /// Report corresponding to the selected project.
    private lazy var reportForCurrentProject: SignalProducer<TwoPartTimeReport?, NoError> = projectId
        .throttle(while: readReport.map { $0 == nil }, on: UIScheduler())
        .combineLatest(with: readReport.producer.skipNil())
        .map { projectId, readGoal in readGoal(projectId) }
        .flatten(.latest) // TODO: generalize and reuse

    // MARK: - Contained view controllers

    private lazy var goalReportViewController: GoalReportViewController = {
        let goalReport = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("GoalReportViewController")) as! GoalReportViewController
        goalReport <~ SignalProducer(
            value: (projectId: projectId,
                    goal: goalForCurrentProject.skipNil(),
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
        noGoal <~ SignalProducer.combineLatest(
            SignalProducer(value: projectId.producer),
            lastBinding.producer.skipNil().map { $0.writeGoal })
            .map {
                (projectId: $0,
                 goalCreated: $1)
        }
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
            goalController <~
                SignalProducer.combineLatest(
                    lastBinding.producer.skipNil().map { $0.calendar },
                    SignalProducer(value: goalForCurrentProject.producer),
                    SignalProducer(value: updateDeleteGoal.bindingTarget))
                    .map {
                        (calendar: $0,
                         goal: $1,
                         userUpdates: $2)
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
        readGoal <~ lastValidBinding.map { $0.readGoal }
        readReport <~ lastValidBinding.map { $0.readReport }

        lifetime += updateDeleteGoal.producer.skipNil().bindOnlyToLatest(lastValidBinding.map { $0.writeGoal })
        lifetime += projectId.producer.sample(on: updateDeleteGoal.signal.filter { $0 == nil}.map { _ in () }).bindOnlyToLatest(lastValidBinding.map { $0.deleteGoal })

        setupLocalProjectDisplay()
        setupConditionalVisibilityOfContainedViews()
    }

    private func setupLocalProjectDisplay() {
        project.producer.observe(on: UIScheduler()).startWithValues { [unowned self] projectOrNil in
            self.projectName.stringValue = projectOrNil?.name ?? ""
        }
    }
}
