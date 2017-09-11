//
//  GoalReportViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

fileprivate let GoalProgressVCContainment = "GoalProgressVCContainment"
fileprivate let GoalStrategyVCContainment = "GoalStrategyVCContainment"
fileprivate let DayProgressVCContainment = "DayProgressVCContainment"

class GoalReportViewController: NSViewController, ViewControllerContaining {

    // MARK: - Interface

    var projectId: BindingTarget<Int64?> { return _projectId.bindingTarget }
    var goal: BindingTarget<TimeGoal?> { return _goal.bindingTarget }
    var report: BindingTarget<TwoPartTimeReport?> { return _report.bindingTarget }
    var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }
    var calendar: BindingTarget<Calendar?> { return _calendar.bindingTarget }
    var now: BindingTarget<Date?> { return _now.bindingTarget }

    private let _projectId = MutableProperty<Int64?>(nil)
    private let _goal = MutableProperty<TimeGoal?>(nil)
    private let _report = MutableProperty<TwoPartTimeReport?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _now = MutableProperty<Date?>(nil)

    // MARK: - Outputs computed for children VCs

    private let goalProgress = MutableProperty<GoalProgress?>(nil)
    private let goalStrategy = MutableProperty<GoalStrategy?>(nil)
    private let dayProgress = MutableProperty<DayProgress?>(nil)


    // MARK: - Private properties

    private let computeStrategyFrom = MutableProperty<DayComponents?>(nil)
    private let selectedComputeStrategyFrom = MutableProperty<NSMenuItem?>(nil)

    
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
            goalProgressViewController.goalProgress <~ goalProgress
            displayController(goalProgressViewController, in: goalProgressView)
        }
    }
    
    var goalStrategyViewController: GoalStrategyViewController! {
        didSet {
            goalStrategyViewController.goalStrategy <~ goalStrategy
            displayController(goalStrategyViewController, in : goalStrategyView)
        }
    }
    
    var dayProgressViewController: DayProgressViewController! {
        didSet {
            dayProgressViewController.dayProgress <~ dayProgress
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


    // MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for identifier in [GoalProgressVCContainment, GoalStrategyVCContainment, DayProgressVCContainment] {
            performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: identifier), sender: self)
        }
        
        wireMonthName()
        setupComputeStrategyFromButton()
        wireStrategyComputation()
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

    private func wireMonthName() {
        monthNameLabel.reactive.text <~ SignalProducer.combineLatest(_calendar.producer.skipNil(), _now.producer.skipNil()).map({ (calendar, now) -> String in
            let comps = calendar.dateComponents([.month], from: now)
            let monthName = calendar.monthSymbols[comps.month! - 1]
            return monthName
        })
    }
    
    private func setupComputeStrategyFromButton() {
        // TODO: save and restore state of computeStrategyFromButton / decide on whether state is global or project specific
        computeStrategyFromButton.select(fromTodayItem)

        selectedComputeStrategyFrom.value = computeStrategyFromButton.selectedItem
        selectedComputeStrategyFrom <~ computeStrategyFromButton.reactive.selectedItems.logEvents()

        computeStrategyFrom <~ SignalProducer.combineLatest(selectedComputeStrategyFrom.producer.skipNil(),
                                                            _now.producer.skipNil(),
                                                            _calendar.producer.skipNil())
            .map { [fromTodayItem, fromNextWorkDayItem] (menuItem, now, calendar) -> DayComponents? in
                guard let fromTodayItem = fromTodayItem, let fromNextWorkDayItem = fromNextWorkDayItem else {
                    return nil
                }
                switch menuItem {
                case fromTodayItem: return calendar.dayComponents(from: now)
                case fromNextWorkDayItem: return try! calendar.nextDay(for: now, notAfter: calendar.lastDayOfMonth(for: now))
                default: return nil
                }
        }

        let enabledTarget = fromNextWorkDayItem.reactive.makeBindingTarget(on: UIScheduler()) { (menuItem, isLastDayOfMonth) in
            menuItem.isEnabled = !isLastDayOfMonth
        }
        
        let isLastDayOfMonth = SignalProducer.combineLatest(_now.producer.skipNil(), _calendar.producer.skipNil()).map { (now, calendar) -> Bool in
            return calendar.dayComponents(from: now) == calendar.lastDayOfMonth(for: now)
        }
        
        enabledTarget <~ isLastDayOfMonth
    }
    
    private func wireStrategyComputation() {
        let computation = SignalProducer.combineLatest(_projectId.producer.skipNil(), // TODO: skip and use binding target / pipe, non optional values
                                                       _goal.producer.skipNil(),
                                                       _report.producer,
                                                       _calendar.producer.skipNil(),
                                                       _now.producer.skipNil(),
                                                       _runningEntry.producer,
                                                       computeStrategyFrom.producer.skipNil())
            .map { (projectId, goal, report, calendar, now, runningEntry, computeFrom) -> (GoalProgress, GoalStrategy, DayProgress) in
                let strategyComputer = StrategyComputer(calendar: calendar)
                strategyComputer.projectId = projectId
                strategyComputer.goal = goal
                strategyComputer.report = report
                strategyComputer.runningEntry = runningEntry
                strategyComputer.now = now
                strategyComputer.startPeriodDay = calendar.firstDayOfMonth(for: now)
                strategyComputer.endPeriodDay = calendar.lastDayOfMonth(for: now)
                strategyComputer.startStrategyDay = computeFrom

            return (strategyComputer.goalProgress, strategyComputer.goalStrategy, strategyComputer.dayProgress)
        }

        goalProgressViewController.goalProgress <~ computation.map { $0.0 }
        goalStrategyViewController.goalStrategy <~ computation.map { $0.1 }
        dayProgressViewController.dayProgress <~ computation.map { $0.2 }
    }
}
