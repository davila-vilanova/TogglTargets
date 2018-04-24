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

fileprivate let GoalVCContainment = "GoalVCContainment"
fileprivate let GoalReportVCContainment = "GoalReportVCContainment"
fileprivate let NoGoalVCContainment = "NoGoalVCContainment"

class ProjectDetailsViewController: NSViewController, ViewControllerContaining, BindingTargetProvider {

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

    var goalViewController: GoalViewController!

    var goalReportViewController: GoalReportViewController!

    var noGoalViewController: NoGoalViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller { // TODO: rework cases
        case _ where (controller as? GoalViewController) != nil:
            goalViewController = controller as! GoalViewController
        case _ where (controller as? GoalReportViewController) != nil:
            goalReportViewController = controller as! GoalReportViewController
        case _ where (controller as? NoGoalViewController) != nil:
            noGoalViewController = controller as! NoGoalViewController
        default: break
        }
    }

    private func setupContainedViewControllerVisibility() {
        displayController(goalViewController, in: goalView) // Display always

        goalForCurrentProject.filter { $0 == nil }.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            displayController(self.noGoalViewController, in: self.goalReportView)
        }

        goalForCurrentProject.filter { $0 != nil }.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            displayController(self.goalReportViewController, in: self.goalReportView)
        }
    }


    // MARK: - Outlets

    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var goalView: NSView!
    @IBOutlet weak var goalReportView: NSView!


    //  MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [GoalVCContainment, GoalReportVCContainment, NoGoalVCContainment])

        project <~ lastBinding.latestOutput { $0.project }

        let lastValidBinding = lastBinding.producer.skipNil()
        readGoal <~ lastValidBinding.map { $0.readGoal }
        readReport <~ lastValidBinding.map { $0.readReport }

        goalReportViewController <~ SignalProducer(
            value: (projectId: projectId,
                    goal: goalForCurrentProject.skipNil(),
                    report: reportForCurrentProject,
                    runningEntry: lastBinding.latestOutput { $0.runningEntry },
                    calendar: lastBinding.latestOutput { $0.calendar },
                    currentDate: lastBinding.latestOutput { $0.currentDate },
                    periodPreference: lastBinding.latestOutput { $0.periodPreference }))

        let updateDeleteGoal = MutableProperty<Goal?>(nil)
        lifetime.observeEnded {
            _ = updateDeleteGoal
        }

        self.goalViewController <~
            SignalProducer.combineLatest(
                lastValidBinding.map { $0.calendar },
                SignalProducer(value: goalForCurrentProject.producer),
                SignalProducer(value: updateDeleteGoal.bindingTarget))
                .map {
                    (calendar: $0,
                     goal: $1,
                     userUpdates: $2)
        }

        self.noGoalViewController <~
            SignalProducer.combineLatest(
                SignalProducer(value: projectId.producer),
                lastValidBinding.map { $0.writeGoal })
                .map {
                    (projectId: $0,
                     goalCreated: $1)
        }

        lifetime += updateDeleteGoal.producer.skipNil().bindOnlyToLatest(lastValidBinding.map { $0.writeGoal })
        lifetime += projectId.producer.sample(on: updateDeleteGoal.producer.filter { $0 == nil}.map { _ in () }).bindOnlyToLatest(lastValidBinding.map { $0.deleteGoal })

        setupLocalProjectDisplay()
        setupContainedViewControllerVisibility()

    }

    private func setupLocalProjectDisplay() {
        project.producer.observe(on: UIScheduler()).startWithValues { [unowned self] projectOrNil in
            self.projectName.stringValue = projectOrNil?.name ?? (projectOrNil != nil ? "(unnamed project)" : "(no project selected)")
        }
    }
}

class ColoredView: NSView {
    var backgroundColor: NSColor? {
        didSet {
            let cgColor: CGColor?
            if let color = backgroundColor {
                cgColor = color.cgColor
            } else {
                cgColor = nil
            }

            // TODO: learn about the right timing to apply the color without this megahack
            let delay = DispatchTime.now() + .seconds(1)
            DispatchQueue.main.asyncAfter(deadline: delay) {
                self.layer?.backgroundColor = cgColor
            }
        }
    }
}
