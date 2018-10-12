//
//  GoalStrategyViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class GoalStrategyViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: Interface

    internal typealias Interface = (
        timeGoal: SignalProducer<TimeInterval, NoError>,
        dayBaseline: SignalProducer<TimeInterval?, NoError>,
        dayBaselineAdjustedToProgress: SignalProducer<TimeInterval?, NoError>,
        dayBaselineDifferential: SignalProducer<Double?, NoError>,
        feasibility: SignalProducer<GoalFeasibility?, NoError>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Formatters

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


    // MARK: - Outlets

    @IBOutlet weak var totalHoursStrategyField: NSTextField!
    @IBOutlet weak var baselineField: NSTextField!
    @IBOutlet weak var baselineDifferentialField: NSTextField!


    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        let timeGoal = lastBinding.latestOutput { $0.timeGoal }
        let dayBaseline = lastBinding.latestOutput { $0.dayBaseline }
        let dayBaselineAdjustedToProgress = lastBinding.latestOutput { $0.dayBaselineAdjustedToProgress }
        let dayBaselineDifferential = lastBinding.latestOutput { $0.dayBaselineDifferential }
        let feasibility = lastBinding.latestOutput { $0.feasibility }

        // Update total hours and hours per day with the values of the corresponding signals
        totalHoursStrategyField.reactive.text <~ timeGoal.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("goal-strategy.header",
                                      comment: "header of the strategy section -- describing the target hours of the goal"),
                    $0)
        }
        baselineField.reactive.text <~ dayBaselineAdjustedToProgress.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("goal-strategy.adjusted-baseline",
                                      comment: "amount of time to work per day to achieve the goal (adjusted day baseline)"),
                    $0)
        }

        let formattedDifferential = dayBaselineDifferential
            .map { $0?.magnitude }
            .map { (differential) -> NSNumber? in
            guard let differential = differential else { return nil }
            return NSNumber(value: differential)
            }
            .mapToNumberFormattedString(numberFormatter: percentFormatter)

        let baselineCalculationErrors = SignalProducer.combineLatest(dayBaselineAdjustedToProgress.filter { $0 == nil },
                                                                     dayBaseline.filter { $0 == nil },
                                                                     dayBaselineDifferential.filter { $0 == nil },
                                                                     feasibility.filter { $0 == nil })
            .map { _ in NSLocalizedString("goal-strategy.cannot-calculate-baseline",
                                          comment: "the adjusted day baseline could not be calculated") }

        let feasibleCaseDescriptions =
            SignalProducer.combineLatest(feasibility.skipNil(),
                                         dayBaselineDifferential.skipNil(),
                                         formattedDifferential,
                                         dayBaseline.skipNil(),
                                         dayBaseline.mapToString(timeFormatter: timeFormatter))
                .filter { (feasibility, _, _, _, _) in
                    return feasibility.isFeasible
                }.map { (_, differential, formattedDifferential, baseline, formattedBaseline) -> String in
                    if abs(differential) < 0.01 {
                        return String.localizedStringWithFormat(
                            NSLocalizedString("goal-strategy.adusted-baseline-matches",
                                              comment: "the adjusted baseline approximately matches the a priori baseline"),
                            formattedBaseline)
                    } else if differential > 0 {
                        return String.localizedStringWithFormat(
                            NSLocalizedString("goal-strategy.differential.more",
                                              comment: "need to catch up to achieve the goal"),
                            formattedDifferential, formattedBaseline)
                    } else {
                        return String.localizedStringWithFormat(
                            NSLocalizedString("goal-strategy.differential.less",
                                              comment: "could work less and still achieve the goal"),
                            formattedDifferential, formattedBaseline)
                    }
        }

        let unfeasibleCaseDescriptions = feasibility.skipNil().filter { $0.isUnfeasible }
            .map { _ in
                NSLocalizedString("goal-strategy.unfeasible",
                                          comment: "reaching the goal is unfeasible but not impossible")
        }

        let impossibleCaseDescriptions = feasibility.skipNil().filter { $0.isImpossible }
            .map { _ in
                NSLocalizedString("goal-strategy.impossible",
                                  comment: "reaching the goal is impossible")
        }

        baselineDifferentialField.reactive.stringValue <~
            SignalProducer.merge(feasibleCaseDescriptions, unfeasibleCaseDescriptions, impossibleCaseDescriptions, baselineCalculationErrors)
    }
    
    // MARK: - Onboarding
    
    var onboardingTargetViews: [OnboardingStep.Identifier : SignalProducer<NSView, NoError>] {
        let goalStrategyView = viewDidLoadProducer
            .map { [unowned self] _ in self.view }
            .concat(SignalProducer.never)
        return [.seeGoalStrategy : goalStrategyView]
    }
}

// MARK: -

class GoalReachedViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: - Interface

    internal typealias Interface = SignalProducer<TimeInterval, NoError>

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()

    @IBOutlet weak var goalReachedField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        let timeGoal = lastBinding.latestOutput { $0 }
        goalReachedField.reactive.text <~ timeGoal.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("goal-reached", comment: "the goal has been achieved"),
                    $0)
        }
    }
    
    
    // MARK: - Onboarding
    
    var onboardingTargetViews: [OnboardingStep.Identifier : SignalProducer<NSView, NoError>] {
        let goalStrategyView = viewDidLoadProducer
            .map { [unowned self] _ in self.view }
            .concat(SignalProducer.never)
        return [.seeGoalStrategy : goalStrategyView]
    }
}
