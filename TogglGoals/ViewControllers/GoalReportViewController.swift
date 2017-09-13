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
    var goal: BindingTarget<Goal?> { return _goal.bindingTarget }
    var report: BindingTarget<TwoPartTimeReport?> { return _report.bindingTarget }
    var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }
    var calendar: BindingTarget<Calendar?> { return _calendar.bindingTarget }
    var now: BindingTarget<Date?> { return _now.bindingTarget }

    private let _projectId = MutableProperty<Int64?>(nil)
    private let _goal = MutableProperty<Goal?>(nil)
    private let _report = MutableProperty<TwoPartTimeReport?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _now = MutableProperty<Date?>(nil)


    // MARK: - Computation

    private let goalProgress = GoalProgress()


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
    
    var timeProgressViewController: TimeProgressViewController! {
        didSet {
            timeProgressViewController.timeGoal <~ goalProgress.timeGoal
            timeProgressViewController.totalWorkDays <~ goalProgress.totalWorkDays
            timeProgressViewController.remainingWorkDays <~ goalProgress.remainingWorkDays
            timeProgressViewController.workedTime <~ goalProgress.workedTime
            timeProgressViewController.remainingTimeToGoal <~ goalProgress.remainingTimeToGoal

            displayController(timeProgressViewController, in: goalProgressView)
        }
    }
    
    var goalStrategyViewController: GoalStrategyViewController! {
        didSet {
            goalStrategyViewController.timeGoal <~ goalProgress.timeGoal
            goalStrategyViewController.dayBaseline <~ goalProgress.dayBaseline
            goalStrategyViewController.dayBaselineAdjustedToProgress <~ goalProgress.dayBaselineAdjustedToProgress
            goalStrategyViewController.dayBaselineDifferential <~ goalProgress.dayBaselineDifferential

            displayController(goalStrategyViewController, in: goalStrategyView)
        }
    }
    
    var dayProgressViewController: DayProgressViewController! {
        didSet {
            dayProgressViewController.timeWorkedToday <~ goalProgress.timeWorkedToday
            dayProgressViewController.remainingTimeToDayBaseline <~ goalProgress.remainingTimeToDayBaseline

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
        connectInputsToGoalProgress()
    }
    
    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller {
        case _ where (controller as? TimeProgressViewController) != nil:
            timeProgressViewController = controller as! TimeProgressViewController
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
    
    private func connectInputsToGoalProgress() {
        goalProgress.projectId <~ _projectId
        goalProgress.goal <~ _goal
        goalProgress.report <~ _report
        goalProgress.runningEntry <~ _runningEntry
        goalProgress.startGoalDay <~ SignalProducer.combineLatest(_now.producer.skipNil(),
                                                                  _calendar.producer.skipNil())
            .map { (now, calendar) in
                calendar.firstDayOfMonth(for: now)
        }
        goalProgress.endGoalDay <~ SignalProducer.combineLatest(_now.producer.skipNil(),
                                                                _calendar.producer.skipNil())
            .map { (now, calendar) in
                calendar.lastDayOfMonth(for: now)
        }
        goalProgress.startStrategyDay <~ computeStrategyFrom
        goalProgress.now <~ _now
        goalProgress.calendar <~ _calendar
    }
}
