//
//  ProjectDetailsViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import PureLayout

let GoalViewControllerContainmentSegueId = "GoalVCContainment"
let GoalProgressViewControllerContainmentSegueId = "GoalProgressVCContainment"
let NoGoalProgressViewControllerContainmentSegueId = "NoGoalProgressVCContainment"


class ProjectDetailsViewController: NSViewController, ViewControllerContaining, ModelCoordinatorContaining {
    // MARK: - Outlets
    
    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var createGoalButton: NSButton!
    @IBOutlet weak var deleteGoalButton: NSButton!
    
    @IBOutlet weak var monthNameLabel: NSTextField!
    
    @IBOutlet weak var totalHoursStrategyLabel: NSTextField!
    
    @IBOutlet weak var computeStrategyFromButton: NSPopUpButton!
    @IBOutlet weak var fromTodayItem: NSMenuItem!
    @IBOutlet weak var fromNextWorkDayItem: NSMenuItem!
    
    @IBOutlet weak var hoursPerDayLabel: NSTextField!
    @IBOutlet weak var baselineDifferentialLabel: NSTextField!
    
    @IBOutlet weak var dayProgressBox: NSBox!
    @IBOutlet weak var todayProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var timeWorkedTodayLabel: NSTextField!
    @IBOutlet weak var timeRemainingToWorkTodayLabel: NSTextField!

    // MARK: - Contained view controllers
    
    @IBOutlet weak var goalView: NSView!
    var goalViewController: GoalViewController! {
        didSet {
            goalViewController.calendar = self.calendar
            displayController(goalViewController, in: goalView)
        }
    }
    
    @IBOutlet weak var goalProgressView: NSView!
    var goalProgressViewController: GoalProgressViewController! {
        didSet {
            goalProgressViewController.timeFormatter = timeFormatter
        }
    }
    var noGoalProgressViewController: NoGoalProgressViewController!
    
    private func displayController(_ controller: NSViewController, in parentView: NSView) {
        parentView.substituteSubviews(with: controller.view)
        controller.view.autoPinEdgesToSuperviewEdges()
    }

    // MARK: - Value formatters
    
    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()

    private lazy var percentFormatter: NumberFormatter = {
        var f = NumberFormatter()
        f.numberStyle = .percent
        return f
    }()

    // MARK: - Represented data
    
    private var representedProject: Project?
    private var observedGoalProperty: ObservedProperty<TimeGoal>?
    private var observedReportProperty: ObservedProperty<TwoPartTimeReport>?

    //  MARK: - Infrastructure
    
    var modelCoordinator: ModelCoordinator?
    var now: Date! // Set as the most current date when a project is selected
    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }()

    private var strategyComputer = StrategyComputer(calendar: Calendar(identifier: .iso8601))

    //  MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        for identifier in [GoalViewControllerContainmentSegueId,
                           GoalProgressViewControllerContainmentSegueId,
                           NoGoalProgressViewControllerContainmentSegueId] {
            performSegue(withIdentifier: identifier, sender: self)
        }
        
        displayRepresentedData()

        // TODO: save and restore state of computeStrategyFromButton / decide on whether state is global or project specific
        computeStrategyFromButton.select(fromTodayItem)
        computeStrategyFromToday(fromTodayItem)
    }
    
    internal func onProjectSelected(project: Project) {
        self.representedProject = project
        displayRepresentedData()
        now = Date()
    }

    internal func displayRepresentedData() {
        guard isViewLoaded == true,
            let project = self.representedProject,
            let mc = modelCoordinator else {
            return;
        }

        if let name = project.name {
            projectName.stringValue = name
        } else {
            projectName.stringValue = "(no name)"
        }

        let goalProperty = mc.goalProperty(for: project.id)
        observeGoalProperty(goalProperty).reportImmediately()
        goalViewController?.goalProperty = goalProperty
        
        let reportProperty = mc.reportProperty(for: project.id)
        observedReportProperty?.unobserve()
        observedReportProperty = ObservedProperty<TwoPartTimeReport>(original: reportProperty, valueObserver: { [weak self] (op) in self?.handleReportValue(op.original?.value) })
        observedReportProperty?.reportImmediately()
    }
    
    @discardableResult
    private func observeGoalProperty(_ goalProperty: Property<TimeGoal>) -> ObservedProperty<TimeGoal> {
        observedGoalProperty?.unobserve()
        let observed = ObservedProperty<TimeGoal>(original: goalProperty, valueObserver: goalDidChange, invalidationObserver: goalWasInvalidated)
        observedGoalProperty = observed
        return observed
    }
    
    private func goalDidChange(_ observedGoal: ObservedProperty<TimeGoal>?) {
        let goalExists = (observedGoal?.original?.value != nil)
        createGoalButton.isHidden = goalExists
        deleteGoalButton.isHidden = !goalExists
        
        updateStrategy()
    }
    
    private func goalWasInvalidated() {
        goalDidChange(nil)
    }

    private func handleReportValue(_ report: TimeReport?) {
        updateStrategy()
    }

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        // TODO: use switch
        if let goalVC = controller as? GoalViewController {
            goalViewController = goalVC
            return
        }
        if let goalProgressVC = controller as? GoalProgressViewController {
            goalProgressViewController = goalProgressVC
            return
        }
        if let noGoalProgressVC = controller as? NoGoalProgressViewController {
            noGoalProgressViewController = noGoalProgressVC
            return
        }
    }
    
    @IBAction func computeStrategyFromToday(_ sender: NSMenuItem) {
        let now = Date()
        timeRemainingToWorkTodayLabel.isHidden = false
        strategyComputer.startStrategyDay = calendar.dayComponents(from: now)
        updateStrategy()
    }


    @IBAction func computeStrategyFromNextWorkDay(_ sender: NSMenuItem) {
        let now = Date()
        timeRemainingToWorkTodayLabel.isHidden = true
        do {
            strategyComputer.startStrategyDay = try calendar.nextDay(for: now, notAfter: calendar.lastDayOfMonth(for: now))
            updateStrategy()
        } catch {

        }
    }

    private func updateStrategy() {
        guard let goal = observedGoalProperty?.original?.value,
            let report = observedReportProperty?.original?.value else {
                displayController(noGoalProgressViewController!, in: goalProgressView)
                return
        }
        displayController(goalProgressViewController, in: goalProgressView)
        goalProgressViewController.goalProgress = strategyComputer.goalProgress
        
        strategyComputer.startPeriodDay = calendar.firstDayOfMonth(for: now)
        strategyComputer.endPeriodDay = calendar.lastDayOfMonth(for: now)
        strategyComputer.now = now
        strategyComputer.goal = goal
        strategyComputer.report = report
        strategyComputer.runningEntry = modelCoordinator?.runningEntry.value

        let comps = calendar.dateComponents([.month], from: now)
        let monthName = calendar.monthSymbols[comps.month! - 1]
        monthNameLabel.stringValue = monthName

        totalHoursStrategyLabel.stringValue = timeFormatter.string(from: strategyComputer.timeGoal)!
        hoursPerDayLabel.stringValue = timeFormatter.string(from: strategyComputer.dayBaselineAdjustedToProgress)!


        let dayBaseline = timeFormatter.string(from: strategyComputer.dayBaseline)!
        let dayBaselineDifferential = strategyComputer.dayBaselineDifferential
        let absoluteBaselineDifferential = abs(dayBaselineDifferential)

        let baselineDifferentialText: String

        if absoluteBaselineDifferential < 0.01 {
            baselineDifferentialText = "That prety much matches your baseline of \(dayBaseline)"
        } else {
            let formattedBaselineDifferential = percentFormatter.string(from: NSNumber(value: abs(dayBaselineDifferential)))!
            if dayBaselineDifferential > 0 {
                baselineDifferentialText = "That is \(formattedBaselineDifferential) more than your baseline of \(dayBaseline)"
            } else {
                baselineDifferentialText = "That is \(formattedBaselineDifferential) less than your baseline of \(dayBaseline)"
            }
        }

        baselineDifferentialLabel.stringValue = baselineDifferentialText

        let formattedTimeWorkedToday = timeFormatter.string(from: strategyComputer.workedTimeToday)!
        timeWorkedTodayLabel.stringValue = "\(formattedTimeWorkedToday) worked today"

        if strategyComputer.isComputingStrategyFromToday {
//            let hasWorkedToday = strategyComputer.workedTimeToday > 0
            let formattedTimeRemainingToWorkToday = timeFormatter.string(from: strategyComputer.remainingTimeToDayBaselineToday)!
            timeRemainingToWorkTodayLabel.stringValue = "\(formattedTimeRemainingToWorkToday) left to meet your goal today"
            todayProgressIndicator.isIndeterminate = false
            todayProgressIndicator.maxValue = strategyComputer.dayBaselineAdjustedToProgress
            todayProgressIndicator.doubleValue = strategyComputer.workedTimeToday
        } else {
            todayProgressIndicator.doubleValue = 0
            if strategyComputer.runningEntryBelongsToProject {
                todayProgressIndicator.isIndeterminate = true
                todayProgressIndicator.startAnimation(self)
            } else {
                todayProgressIndicator.isIndeterminate = false
                todayProgressIndicator.stopAnimation(self)
            }
        }
    }

    @IBAction func createGoal(_ sender: Any) {
        guard observedGoalProperty?.original?.value == nil,
            let modelCoordinator = self.modelCoordinator,
            let projectId = representedProject?.id else {
                return
        }
        let goal = TimeGoal(forProjectId: projectId, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend)
        modelCoordinator.setNewGoal(goal)
    }

    @IBAction func deleteGoal(_ sender: Any) {
        guard let goal = observedGoalProperty?.original?.value,
            let modelCoordinator = self.modelCoordinator else {
                return
        }
        modelCoordinator.deleteGoal(goal)
    }
}
