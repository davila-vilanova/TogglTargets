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

class GoalReportViewController: NSViewController, BindingTargetProvider {

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

    lazy private var goalStrategyViewController: GoalStrategyViewController = {
        let goalStrategy = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("GoalStrategyViewController")) as! GoalStrategyViewController
        goalStrategy <~
            SignalProducer(value: (timeGoal: goalProgress.timeGoal,
                                   dayBaseline: goalProgress.dayBaseline,
                                   dayBaselineAdjustedToProgress: goalProgress.dayBaselineAdjustedToProgress,
                                   dayBaselineDifferential: goalProgress.dayBaselineDifferential,
                                   feasibility: goalProgress.feasibility))
        addChildViewController(goalStrategy)
        return goalStrategy
    }()

    lazy private var goalReachedViewController: GoalReachedViewController = {
        let goalReached = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("GoalReachedViewController")) as! GoalReachedViewController
        goalReached <~ SignalProducer(value: goalProgress.timeGoal)
        addChildViewController(goalReached)
        return goalReached
    }()

    var dayProgressViewController: DayProgressViewController! {
        didSet {
            dayProgressViewController <~
                SignalProducer(value: (timeWorkedToday: goalProgress.timeWorkedToday.producer,
                                       remainingTimeToDayBaseline: goalProgress.remainingTimeToDayBaseline.producer,
                                       feasibility: goalProgress.feasibility))
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let timeProgress = segue.destinationController as? TimeProgressViewController {
            timeProgressViewController = timeProgress
        } else if let dayProgress = segue.destinationController as? DayProgressViewController {
            dayProgressViewController = dayProgress
        }
    }

    private func setupCondicionalVisibilityOfContainedViews() {
        let isGoalReached = goalProgress.remainingTimeToGoal
            .map { (remainingTime: TimeInterval) -> Bool in
                remainingTime == 0
        }

        let selectedGoalStrategyController = isGoalReached.producer.map { [goalStrategyViewController, goalReachedViewController] (isGoalReached: Bool) -> NSViewController in
            return isGoalReached ? goalReachedViewController : goalStrategyViewController
            }

        goalStrategyView.reactive.makeBindingTarget { (parent: NSView, children: (NSView?, NSView)) in
            if let previous = children.0 {
                previous.removeFromSuperview()
            }
            let child = children.1
            child.translatesAutoresizingMaskIntoConstraints = false
            parent.addSubview(child)

            // Pin edges to superview's edges
            child.topAnchor.constraint(equalTo: parent.topAnchor).isActive = true
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor).isActive = true
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor).isActive = true
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor).isActive = true
            } <~ selectedGoalStrategyController.map { $0.view }.skipRepeats().map { Optional($0) }.combinePrevious(nil).map { ($0.0, $0.1!) }
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

        wirePeriodDescription()
        setupComputeStrategyFromButton()
        connectPropertiesToGoalProgress()
        setupCondicionalVisibilityOfContainedViews()
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
