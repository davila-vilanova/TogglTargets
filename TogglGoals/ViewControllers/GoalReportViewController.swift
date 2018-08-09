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

class GoalReportViewController: NSViewController, ViewControllerContaining, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        projectId: SignalProducer<Int64, NoError>,
        goal: SignalProducer<Goal, NoError>,
        report: SignalProducer<TwoPartTimeReport?, NoError>,
        runningEntry: SignalProducer<RunningEntry?, NoError>,
        calendar: SignalProducer<Calendar, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        periodPreference: SignalProducer<PeriodPreference, NoError>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Properties

    private let calendar = MutableProperty<Calendar?>(nil)
    private let currentDate = MutableProperty<Date?>(nil)
    private let periodPreference = MutableProperty<PeriodPreference?>(nil)

    private let computeStrategyFrom = MutableProperty<DayComponents?>(nil)
    private let selectedComputeStrategyFrom = MutableProperty<NSMenuItem?>(nil)


    // MARK: - Computation

    private let goalProgress = GoalProgress()

    private lazy var goalPeriod: SignalProducer<Period, NoError> =
        SignalProducer.combineLatest(periodPreference.producer.skipNil(),
                                     calendar.producer.skipNil(), currentDate.producer.skipNil())
            .map { $0.currentPeriod(in: $1, for: $2) }


    // MARK: - Outlets
    
    @IBOutlet weak var periodDescriptionLabel: NSTextField!
    @IBOutlet weak var goalStrategyView: NSView!
    @IBOutlet weak var computeStrategyFromButton: NSPopUpButton!
    @IBOutlet weak var fromTodayItem: NSMenuItem!
    @IBOutlet weak var fromNextWorkDayItem: NSMenuItem!


    // MARK: - Contained view controllers
    
    var timeProgressViewController: TimeProgressViewController! {
        didSet {
            timeProgressViewController <~
                SignalProducer(value: (timeGoal: goalProgress.timeGoal,
                                       totalWorkDays: goalProgress.totalWorkDays,
                                       remainingWorkDays: goalProgress.remainingWorkDays,
                                       reportAvailable: goalProgress.reportAvailable.producer,
                                       workedTime: goalProgress.workedTime,
                                       remainingTimeToGoal: goalProgress.remainingTimeToGoal,
                                       strategyStartsToday: goalProgress.strategyStartsToday))
        }
    }

    var goalStrategyViewController: GoalStrategyViewController! {
        didSet {
            goalStrategyViewController <~
                SignalProducer(value: (timeGoal: goalProgress.timeGoal,
                                       dayBaseline: goalProgress.dayBaseline,
                                       dayBaselineAdjustedToProgress: goalProgress.dayBaselineAdjustedToProgress,
                                       dayBaselineDifferential: goalProgress.dayBaselineDifferential,
                                       feasibility: goalProgress.feasibility))
        }
    }

    var goalReachedViewController: GoalReachedViewController! {
        didSet {
            goalReachedViewController <~ SignalProducer(value: goalProgress.timeGoal)
        }
    }

    var dayProgressViewController: DayProgressViewController! {
        didSet {
            dayProgressViewController <~
                SignalProducer(value: (timeWorkedToday: goalProgress.timeWorkedToday.producer,
                                       remainingTimeToDayBaseline: goalProgress.remainingTimeToDayBaseline.producer,
                                       feasibility: goalProgress.feasibility))
        }
    }

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller {
        case _ where (controller as? GoalStrategyViewController) != nil:
            goalStrategyViewController = controller as! GoalStrategyViewController
        case _ where (controller as? GoalReachedViewController) != nil:
            goalReachedViewController = controller as! GoalReachedViewController
        default: break
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let timeProgress = segue.destinationController as? TimeProgressViewController {
            timeProgressViewController = timeProgress
        } else if let dayProgress = segue.destinationController as? DayProgressViewController {
            dayProgressViewController = dayProgress
        }
    }

    private func setupContainedViewControllerVisibility() {
        let isGoalReached = goalProgress.remainingTimeToGoal
            .map { (remainingTime: TimeInterval) -> Bool in
                remainingTime == 0.0
        }

        let selectedGoalStrategyController = isGoalReached.map { [goalStrategyViewController, goalReachedViewController] (isGoalReached: Bool) -> NSViewController in
            return isGoalReached ? goalReachedViewController! : goalStrategyViewController!
        }

        setupContainment(of: selectedGoalStrategyController, in: self, view: goalStrategyView)
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

    private lazy var periodDescriptionFormatter = calendar.producer.map { cal -> DateFormatter in
        let f = DateFormatter()
        f.calendar = cal
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }


    // MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        goalProgress.projectId <~ lastBinding.latestOutput { $0.projectId }
        goalProgress.goal <~ lastBinding.latestOutput { $0.goal }
        goalProgress.report <~ lastBinding.latestOutput {$0.report }
        goalProgress.runningEntry <~ lastBinding.latestOutput { $0.runningEntry }
        calendar <~ lastBinding.latestOutput { $0.calendar }
        currentDate <~ lastBinding.latestOutput { $0.currentDate }
        periodPreference <~ lastBinding.latestOutput { $0.periodPreference }

        for identifier in [GoalProgressVCContainment, GoalStrategyVCContainment, GoalReachedVCContainment, DayProgressVCContainment] {
            performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: identifier), sender: self)
        }
        
        wirePeriodDescription()
        setupComputeStrategyFromButton()
        connectPropertiesToGoalProgress()
        setupContainedViewControllerVisibility()
    }

    
    // MARK: -

    private func wirePeriodDescription() {
        periodDescriptionLabel.reactive.text <~ SignalProducer.combineLatest(goalPeriod.producer,
                                                                             periodDescriptionFormatter,
                                                                             calendar.producer.skipNil())
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
                                                            currentDate.producer.skipNil(),
                                                            calendar.producer.skipNil())
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
        
        let isLastDayOfMonth = SignalProducer.combineLatest(currentDate.producer.skipNil(), calendar.producer.skipNil())
            .map { (currentDate, calendar) -> Bool in
                return calendar.dayComponents(from: currentDate) == calendar.lastDayOfMonth(for: currentDate)
        }

        enabledTarget <~ isLastDayOfMonth
    }
    
    private func connectPropertiesToGoalProgress() {
        goalProgress.startGoalDay <~ goalPeriod.map { $0.start }
        goalProgress.endGoalDay <~ goalPeriod.map { $0.end }
        goalProgress.startStrategyDay <~ computeStrategyFrom.producer.skipNil()
        goalProgress.currentDate <~ currentDate.producer.skipNil()
        goalProgress.calendar <~ calendar.producer.skipNil()
    }
}
