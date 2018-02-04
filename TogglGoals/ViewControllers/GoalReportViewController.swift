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
fileprivate let GoalReachedVCContainment = "GoalReachedVCContainment"
fileprivate let DayProgressVCContainment = "DayProgressVCContainment"

class GoalReportViewController: NSViewController, ViewControllerContaining {

    // MARK: Exposed targets

    var projectId: BindingTarget<Int64> { return goalProgress.projectId }
    var goal: BindingTarget<Goal> { return goalProgress.goal }
    var report: BindingTarget<TwoPartTimeReport?> { return goalProgress.report.bindingTarget }
    var runningEntry: BindingTarget<RunningEntry?> { return goalProgress.runningEntry.bindingTarget }
    var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    var currentDate: BindingTarget<Date> { return _currentDate.deoptionalizedBindingTarget }
    var periodPreference: BindingTarget<PeriodPreference> { return _periodPreference.deoptionalizedBindingTarget }


    // MARK: - Properties

    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _currentDate = MutableProperty<Date?>(nil)
    private let _periodPreference = MutableProperty<PeriodPreference?>(nil)

    private let computeStrategyFrom = MutableProperty<DayComponents?>(nil)
    private let selectedComputeStrategyFrom = MutableProperty<NSMenuItem?>(nil)


    // MARK: - Computation

    private let goalProgress = GoalProgress()

    private lazy var goalPeriod: SignalProducer<Period, NoError> =
        SignalProducer.combineLatest(_periodPreference.producer.skipNil(),
                                     _calendar.producer.skipNil(), _currentDate.producer.skipNil())
            .map { $0.currentPeriod(in: $1, for: $2) }


    // MARK: - Outlets
    
    @IBOutlet weak var periodDescriptionLabel: NSTextField!
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
            timeProgressViewController.strategyStartsToday <~ goalProgress.strategyStartsToday
        }
    }
    
    var goalStrategyViewController: GoalStrategyViewController! {
        didSet {
            goalStrategyViewController.connectInputs(timeGoal: goalProgress.timeGoal,
                                                     dayBaseline: goalProgress.dayBaseline,
                                                     dayBaselineAdjustedToProgress: goalProgress.dayBaselineAdjustedToProgress,
                                                     dayBaselineDifferential: goalProgress.dayBaselineDifferential)
        }
    }

    var goalReachedViewController: GoalReachedViewController! {
        didSet {
            goalReachedViewController.timeGoal <~ goalProgress.timeGoal
        }
    }

    var dayProgressViewController: DayProgressViewController! {
        didSet {
            dayProgressViewController.connectInputs(timeWorkedToday: goalProgress.timeWorkedToday.producer,
                                                    remainingTimeToDayBaseline: goalProgress.remainingTimeToDayBaseline.producer)
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

    private lazy var periodDescriptionFormatter = _calendar.producer.map { cal -> DateFormatter in
        let f = DateFormatter()
        f.calendar = cal
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }

    // MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for identifier in [GoalProgressVCContainment, GoalStrategyVCContainment, GoalReachedVCContainment, DayProgressVCContainment] {
            performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: identifier), sender: self)
        }
        
        wirePeriodDescription()
        setupComputeStrategyFromButton()
        connectPropertiesToGoalProgress()
        setupContainedViewControllerVisibility()
    }
    
    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller {
        case _ where (controller as? TimeProgressViewController) != nil:
            timeProgressViewController = controller as! TimeProgressViewController
        case _ where (controller as? GoalStrategyViewController) != nil:
            goalStrategyViewController = controller as! GoalStrategyViewController
        case _ where (controller as? GoalReachedViewController) != nil:
            goalReachedViewController = controller as! GoalReachedViewController
        case _ where (controller as? DayProgressViewController) != nil:
            dayProgressViewController = controller as! DayProgressViewController
        default: break
        }
    }

    private func setupContainedViewControllerVisibility() {
        displayController(timeProgressViewController, in: goalProgressView) // Display always
        displayController(dayProgressViewController, in: dayProgressView) // Display always

        goalProgress.remainingTimeToGoal
            .map { (remainingTime: TimeInterval) -> Bool in
                remainingTime == 0.0
            }
            .map { [goalStrategyViewController, goalReachedViewController] (isGoalReached: Bool) -> NSViewController in
                return isGoalReached ? goalReachedViewController! : goalStrategyViewController!
            }
            .observe(on: UIScheduler()).startWithValues { [unowned self] (controller) in
                displayController(controller, in: self.goalStrategyView)
        }
    }
    
    // MARK: -

    private func wirePeriodDescription() {
        periodDescriptionLabel.reactive.text <~ SignalProducer.combineLatest(goalPeriod.producer,
                                                                             periodDescriptionFormatter,
                                                                             _calendar.producer.skipNil())
            .map { (period, formatter, calendar) in
                // Assuming that period has been automatically generated and thus the day components are valid and the calls won't throw
                let startDate = try! calendar.date(from: period.start)
                let endDate = try! calendar.date(from: period.end)
                let formattedStart = formatter.string(from: startDate)
                let formattedEnd = formatter.string(from: endDate)
                return "\(formattedStart) - \(formattedEnd)" // TODO: Localizable
        }
    }
    
    private func setupComputeStrategyFromButton() {
        // TODO: save and restore state of computeStrategyFromButton / decide on whether state is global or project specific
        computeStrategyFromButton.select(fromTodayItem)

        selectedComputeStrategyFrom.value = computeStrategyFromButton.selectedItem
        selectedComputeStrategyFrom <~ computeStrategyFromButton.reactive.selectedItems

        computeStrategyFrom <~ SignalProducer.combineLatest(selectedComputeStrategyFrom.producer.skipNil(),
                                                            _currentDate.producer.skipNil(),
                                                            _calendar.producer.skipNil())
            .map { [fromTodayItem, fromNextWorkDayItem] (menuItem, currentDate, calendar) -> DayComponents? in
                guard let fromTodayItem = fromTodayItem, let fromNextWorkDayItem = fromNextWorkDayItem else {
                    return nil
                }
                switch menuItem {
                case fromTodayItem: return calendar.dayComponents(from: currentDate)
                case fromNextWorkDayItem: return try! calendar.nextDay(for: currentDate,
                                                                       notAfter: calendar.lastDayOfMonth(for: currentDate))
                default: return nil
                }
        }

        let enabledTarget = fromNextWorkDayItem.reactive.makeBindingTarget(on: UIScheduler()) { (menuItem, isLastDayOfMonth) in
            menuItem.isEnabled = !isLastDayOfMonth
        }
        
        let isLastDayOfMonth = SignalProducer.combineLatest(_currentDate.producer.skipNil(), _calendar.producer.skipNil())
            .map { (currentDate, calendar) -> Bool in
                return calendar.dayComponents(from: currentDate) == calendar.lastDayOfMonth(for: currentDate)
        }

        enabledTarget <~ isLastDayOfMonth
    }
    
    private func connectPropertiesToGoalProgress() {
        goalProgress.startGoalDay <~ goalPeriod.map { $0.start }
        goalProgress.endGoalDay <~ goalPeriod.map { $0.end }
        goalProgress.startStrategyDay <~ computeStrategyFrom.producer.skipNil()
        goalProgress.currentDate <~ _currentDate.producer.skipNil()
        goalProgress.calendar <~ _calendar.producer.skipNil()
    }
}
