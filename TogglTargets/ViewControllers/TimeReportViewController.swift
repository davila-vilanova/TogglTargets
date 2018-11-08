//
//  TimeReportViewController.swift
//  TogglTargets
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

class TimeReportViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: Interface

    internal typealias Interface = (
        projectId: SignalProducer<Int64, NoError>,
        timeTarget: SignalProducer<TimeTarget, NoError>,
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

    private let progress = ProgressToTimeTarget()

    private lazy var timePeriod: SignalProducer<Period, NoError> =
        SignalProducer.combineLatest(periodPreference.producer.skipNil(),
                                     calendar.producer.skipNil(), currentDate.producer.skipNil())
            .map { $0.currentPeriod(in: $1, for: $2) }

    // MARK: - Outlets

    @IBOutlet weak var periodDescriptionLabel: NSTextField!
    @IBOutlet weak var strategyView: NSView!
    @IBOutlet weak var computeStrategyFromButton: NSPopUpButton!
    @IBOutlet weak var fromTodayItem: NSMenuItem!
    @IBOutlet weak var fromNextWorkDayItem: NSMenuItem!

    // MARK: - Contained view controllers

    var timeProgressViewController: TimeProgressViewController! {
        didSet {
            timeProgressViewController <~
                SignalProducer(value: (targetTime: progress.targetTime,
                                       totalWorkDays: progress.totalWorkDays,
                                       remainingWorkDays: progress.remainingWorkDays,
                                       reportAvailable: progress.reportAvailable.producer,
                                       workedTime: progress.workedTime,
                                       remainingTimeToTarget: progress.remainingTimeToTarget,
                                       strategyStartsToday: progress.strategyStartsToday))
        }
    }

    private lazy var strategyViewController: StrategyViewController = {
        let strategy = self.storyboard!.instantiateController(withIdentifier: "StrategyViewController")
            as! StrategyViewController // swiftlint:disable:this force_cast
        strategy <~
            SignalProducer(value: (targetTime: progress.targetTime,
                                   dayBaseline: progress.dayBaseline,
                                   dayBaselineAdjustedToProgress: progress.dayBaselineAdjustedToProgress,
                                   dayBaselineDifferential: progress.dayBaselineDifferential,
                                   feasibility: progress.feasibility))
        addChild(strategy)
        return strategy
    }()

    private lazy var targetReachedViewController: TargetReachedViewController = {
        let targetReached = self.storyboard!.instantiateController(withIdentifier: "TargetReachedViewController")
            as! TargetReachedViewController // swiftlint:disable:this force_cast
        targetReached <~ SignalProducer(value: progress.targetTime)
        addChild(targetReached)
        return targetReached
    }()

    var dayProgressViewController: DayProgressViewController! {
        didSet {
            dayProgressViewController <~
                SignalProducer(value: (timeWorkedToday: progress.timeWorkedToday.producer,
                                       remainingTimeToDayBaseline: progress.remainingTimeToDayBaseline.producer,
                                       feasibility: progress.feasibility))
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let timeProgress = segue.destinationController as? TimeProgressViewController {
            timeProgressViewController = timeProgress
        } else if let dayProgress = segue.destinationController as? DayProgressViewController {
            dayProgressViewController = dayProgress
        }
    }

    private func setupConditionalVisibilityOfContainedViews() {
        let isTargetReached = progress.remainingTimeToTarget
            .map { (remainingTime: TimeInterval) -> Bool in
                remainingTime == 0
        }

        let selectedStrategyController = isTargetReached
            .producer
            .observe(on: UIScheduler())
            .map { [strategyViewController, targetReachedViewController] (isTargetReached: Bool) -> NSViewController in
                return isTargetReached ? targetReachedViewController : strategyViewController
        }

        strategyView.uniqueSubview <~ selectedStrategyController.map { $0.view }.skipRepeats()
    }

    // MARK: - Value formatters

    private lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.unitsStyle = .full
        return formatter
    }()

    private lazy var percentFormatter: NumberFormatter = {
        var formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()

    private lazy var periodDescriptionFormatter = calendar.producer.map { cal -> DateFormatter in
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        progress.projectId <~ lastBinding.latestOutput { $0.projectId }
        progress.timeTarget <~ lastBinding.latestOutput { $0.timeTarget }
        progress.report <~ lastBinding.latestOutput {$0.report }
        progress.runningEntry <~ lastBinding.latestOutput { $0.runningEntry }
        calendar <~ lastBinding.latestOutput { $0.calendar }
        currentDate <~ lastBinding.latestOutput { $0.currentDate }
        periodPreference <~ lastBinding.latestOutput { $0.periodPreference }

        wirePeriodDescription()
        setupComputeStrategyFromButton()
        connectPropertiesToProgressToTimeTarget()
        setupConditionalVisibilityOfContainedViews()
    }

    // MARK: -

    private func wirePeriodDescription() {
        periodDescriptionLabel.reactive.text <~ SignalProducer.combineLatest(timePeriod.producer,
                                                                             periodDescriptionFormatter,
                                                                             calendar.producer.skipNil())
            .map { (period, formatter, calendar) in
                guard let startDate = calendar.date(from: period.start),
                    let endDate = calendar.date(from: period.end) else {
                        return NSLocalizedString(
                            "time-report.error-computing-period",
                            comment: "message to display in the time report view when an error occurs while " +
                            "computing the current period")
                }
                let formattedStart = formatter.string(from: startDate)
                let formattedEnd = formatter.string(from: endDate)
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "time-report.period-description",
                        comment: "description of the current period in the time report view"),
                    formattedStart, formattedEnd)
        }
    }

    private func setupComputeStrategyFromButton() {
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
                case fromNextWorkDayItem:
                    return calendar.nextDay(after: calendar.dayComponents(from: currentDate),
                                            notLaterThan: calendar.lastDayOfMonth(for: currentDate))
                default: return nil
                }
        }

        let enableFromNextWorkDayMenuItem = fromNextWorkDayItem.reactive.makeBindingTarget { $0.isEnabled = $1 }
        let nextDay = SignalProducer.combineLatest(calendar.producer.skipNil(),
                                                   currentDate.producer.skipNil(),
                                                   timePeriod.map { $0.end })
            .map { $0.nextDay(after: $0.dayComponents(from: $1), notLaterThan: $2) }
        let remainingWorkdaysInPeriod = SignalProducer.combineLatest(
            calendar.producer.skipNil(),
            lastBinding.latestOutput { $0.timeTarget },
            nextDay,
            timePeriod.map { $0.end })
            .map { $2 == nil ? nil : $0.countWeekdaysMatching($1.workWeekdays, from: $2!, to: $3) }
        enableFromNextWorkDayMenuItem <~ remainingWorkdaysInPeriod.map { ($0 ?? 0) > 0 }
    }

    private func connectPropertiesToProgressToTimeTarget() {
        progress.startDay <~ timePeriod.map { $0.start }
        progress.endDay <~ timePeriod.map { $0.end }
        progress.startStrategyDay <~ computeStrategyFrom.producer.skipNil()
        progress.currentDate <~ currentDate.producer.skipNil()
        progress.calendar <~ calendar.producer.skipNil()
    }

    // MARK: - Onboarding

    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, NoError>] {
        let computeStrategyFromButton = viewDidLoadProducer
            .map { [unowned self] _ in self.computeStrategyFromButton }
            .skipNil()

        let computeStrategyFromSelectionChanged = computeStrategyFromButton
            .map { $0.reactive.selectedItems.map { _ in () } }.flatten(.concat)

        let computeStrategyFromSelectionView = computeStrategyFromButton
            .map { $0 as NSView }
            .concat(SignalProducer.never)
            .take(until: computeStrategyFromSelectionChanged)

        let strategyView = viewDidLoadProducer
            .map { [unowned self] _ in self.strategyView }
            .skipNil()
            .concat(SignalProducer.never)

        return [.selectComputeStrategyFrom: computeStrategyFromSelectionView,
                .seeStrategy: strategyView]
    }
}
