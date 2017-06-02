//
//  GoalReportViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

fileprivate let GoalProgressVCContainment = "GoalProgressVCContainment"
fileprivate let GoalStrategyVCContainment = "GoalStrategyVCContainment"
fileprivate let DayProgressVCContainment = "DayProgressVCContainment"

class GoalReportViewController: NSViewController, ViewControllerContaining {
    
    // MARK: - Outlets
    
    @IBOutlet weak var monthNameLabel: NSTextField!
    @IBOutlet weak var goalProgressView: NSView!
    @IBOutlet weak var goalStrategyView: NSView!
    @IBOutlet weak var dayProgressView: NSView!
    @IBOutlet weak var computeStrategyFromButton: NSPopUpButton!
    @IBOutlet weak var fromTodayItem: NSMenuItem!
    @IBOutlet weak var fromNextWorkDayItem: NSMenuItem!

    // MARK: - Contained view controllers
    
    var goalProgressViewController: GoalProgressViewController! {
        didSet {
            goalProgressViewController.timeFormatter = timeFormatter
            displayController(goalProgressViewController, in: goalProgressView)
        }
    }
    
    var goalStrategyViewController: GoalStrategyViewController! {
        didSet {
            goalStrategyViewController.timeFormatter = timeFormatter
            goalStrategyViewController.percentFormatter = percentFormatter
            displayController(goalStrategyViewController, in : goalStrategyView)
        }
    }
    
    var dayProgressViewController: DayProgressViewController! {
        didSet {
            dayProgressViewController.timeFormatter = timeFormatter
            displayController(dayProgressViewController, in: dayProgressView)
        }
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
    
    private var goalProperty: Property<TimeGoal>? {
        didSet {
            if let observed = observedGoalProperty {
                observed.unobserve()
            }
            if let gp = goalProperty {
                func goalDidChange(_ observedGoalProperty: ObservedProperty<TimeGoal>) {
                    recomputeAndPropagate()
                }
                observedGoalProperty = ObservedProperty<TimeGoal>(original: gp, valueObserver: goalDidChange)
            }
        }
    }
    
    private var reportProperty: Property<TwoPartTimeReport>? {
        didSet {
            if let observed = observedReportProperty {
                observed.unobserve()
            }
            if let rp = reportProperty {
                func reportDidChange(_ observedReportProperty: ObservedProperty<TwoPartTimeReport>) {
                    recomputeAndPropagate()
                }
                observedReportProperty = ObservedProperty<TwoPartTimeReport>(original: rp, valueObserver: reportDidChange)
            }
        }
    }
    
    private var observedGoalProperty: ObservedProperty<TimeGoal>?
    private var observedReportProperty: ObservedProperty<TwoPartTimeReport>?

    func setGoalProperty(_ goalProperty: Property<TimeGoal>, reportProperty: Property<TwoPartTimeReport>) {
        self.goalProperty = goalProperty
        self.reportProperty = reportProperty
        recomputeAndPropagate()
    }
    
    var runningEntryProperty: Property<RunningEntry>! {
        didSet {
            if let observed = observedRunningEntryProperty {
                observedRunningEntryProperty.unobserve()
            }
            func runningEntryDidChange(observedRunningEntry: ObservedProperty<RunningEntry>) {
                recomputeAndPropagate()
            }
            observedRunningEntryProperty = ObservedProperty<RunningEntry>(original: runningEntryProperty, valueObserver: runningEntryDidChange)
        }
    }
    var observedRunningEntryProperty: ObservedProperty<RunningEntry>!
    
    
    // MARK: - Infrastructure
    
    var strategyComputer: StrategyComputer!
    var calendar: Calendar!
    var now: Date!
    
    
    // MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for identifier in [GoalProgressVCContainment, GoalStrategyVCContainment, DayProgressVCContainment] {
            performSegue(withIdentifier: identifier, sender: self)
        }
        
        displayMonthName()
        
        // TODO: save and restore state of computeStrategyFromButton / decide on whether state is global or project specific
        computeStrategyFromButton.select(fromTodayItem)
        
        recomputeAndPropagate()
    }
    
    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller {
        case _ where (controller as? GoalProgressViewController) != nil:
            goalProgressViewController = controller as! GoalProgressViewController
        case _ where (controller as? GoalStrategyViewController) != nil:
            goalStrategyViewController = controller as! GoalStrategyViewController
        case _ where (controller as? DayProgressViewController) != nil:
            dayProgressViewController = controller as! DayProgressViewController
        default: break
        }
    }

    
    // MARK: -

    private func displayMonthName() {
        let comps = calendar.dateComponents([.month], from: now)
        let monthName = calendar.monthSymbols[comps.month! - 1]
        monthNameLabel.stringValue = monthName
    }
    
    private func recomputeAndPropagate() {
        guard isViewLoaded else {
            return
        }
        guard let goal = observedGoalProperty?.original?.value,
            let report = observedReportProperty?.original?.value else {
                return;
        }
        
        // populate inputs
        strategyComputer.goal = goal
        strategyComputer.report = report
        strategyComputer.runningEntry = observedRunningEntryProperty.original?.value

        strategyComputer.now = now
        strategyComputer.startPeriodDay = calendar.firstDayOfMonth(for: now)
        strategyComputer.endPeriodDay = calendar.lastDayOfMonth(for: now)

        if computeStrategyFromButton.selectedItem! === fromTodayItem {
            strategyComputer.startStrategyDay = calendar.dayComponents(from: now)
        } else {
            strategyComputer.startStrategyDay = try! calendar.nextDay(for: now, notAfter: calendar.lastDayOfMonth(for: now)) // TODO
        }

        // assign outputs
        goalProgressViewController.goalProgress = strategyComputer.goalProgress
        goalStrategyViewController.goalStrategy = strategyComputer.goalStrategy
        dayProgressViewController.dayProgress = strategyComputer.dayProgress
    }
    
    @IBAction func computeStrategyFromUpdated(_ sender: NSMenuItem) {
        recomputeAndPropagate()
    }
}
