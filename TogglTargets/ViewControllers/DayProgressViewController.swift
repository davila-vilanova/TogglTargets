//
//  DayProgressViewController.swift
//  TogglTargets
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class DayProgressViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: Interface

    internal typealias Interface = (timeWorkedToday: SignalProducer<TimeInterval, NoError>,
        remainingTimeToDayBaseline: SignalProducer<TimeInterval?, NoError>,
        feasibility: SignalProducer<GoalFeasibility?, NoError>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Private

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()


    // MARK: - Outlets

    @IBOutlet weak var dayProgressBox: NSBox!
    @IBOutlet weak var todayProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var timeWorkedTodayLabel: NSTextField!
    @IBOutlet weak var timeRemainingToWorkTodayLabel: NSTextField!


    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        let timeWorkedToday = lastBinding.latestOutput { $0.timeWorkedToday }
        let remainingTimeToDayBaseline = lastBinding.latestOutput { $0.remainingTimeToDayBaseline }

        // Update worked and remaining time today with the values of the corresponding signals formatted to a time string

        timeWorkedTodayLabel.reactive.text <~ timeWorkedToday.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("day-progress.worked-today", comment: "amount of time worked today"), $0)
        }

        timeRemainingToWorkTodayLabel.reactive.text <~ remainingTimeToDayBaseline.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("day-progress.to-work-today", comment: "amount of time left to meet daily target"), $0)
        }

        // Update progress indicator
        todayProgressIndicator.reactive.makeBindingTarget { (progress, times) in
            let (worked, remaining) = times
            progress.maxValue = worked + remaining
            progress.doubleValue = worked
            } <~ SignalProducer.combineLatest(timeWorkedToday.producer, remainingTimeToDayBaseline.skipNil())

        // Show or hide time remaining and progress indicator
        let isTimeRemainingMissing = remainingTimeToDayBaseline.map { $0 == nil }
        let isGoalImpossible = lastBinding.latestOutput { $0.feasibility }.map { $0?.isImpossible ?? true }
        let hide = isTimeRemainingMissing.or(isGoalImpossible)
        timeRemainingToWorkTodayLabel.reactive.makeBindingTarget { $0.isHidden = $1 } <~ hide
        todayProgressIndicator.reactive.makeBindingTarget { $0.isIndeterminate = $1 } <~ hide
    }
    
    
    // MARK: - Onboarding
    
    var onboardingTargetViews: [OnboardingStepIdentifier : SignalProducer<NSView, NoError>] {
        let dayProgressView = viewDidLoadProducer
            .map { [unowned self] _ in self.view }
            .concat(SignalProducer.never)
        return [.seeDayProgress : dayProgressView]
    }
}
