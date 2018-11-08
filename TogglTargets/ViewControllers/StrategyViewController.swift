//
//  StrategyViewController.swift
//  TogglTargets
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class StrategyViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        targetTime: SignalProducer<TimeInterval, NoError>,
        dayBaseline: SignalProducer<TimeInterval?, NoError>,
        dayBaselineAdjustedToProgress: SignalProducer<TimeInterval?, NoError>,
        dayBaselineDifferential: SignalProducer<Double?, NoError>,
        feasibility: SignalProducer<TargetFeasibility?, NoError>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Private properties

    private lazy var targetTime = lastBinding.latestOutput { $0.targetTime }
    private lazy var dayBaseline = lastBinding.latestOutput { $0.dayBaseline }
    private lazy var dayBaselineAdjustedToProgress = lastBinding.latestOutput { $0.dayBaselineAdjustedToProgress }
    private lazy var dayBaselineDifferential = lastBinding.latestOutput { $0.dayBaselineDifferential }
    private lazy var feasibility = lastBinding.latestOutput { $0.feasibility }

    // MARK: - Formatters

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

    // MARK: - Outlets

    @IBOutlet weak var totalHoursStrategyField: NSTextField!
    @IBOutlet weak var baselineField: NSTextField!
    @IBOutlet weak var baselineDifferentialField: NSTextField!

    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        wireTotalHoursStrategyField()
        wireBaselineField()
        wireBaselineField()
    }

    func wireTotalHoursStrategyField() {
        totalHoursStrategyField.reactive.text <~ targetTime.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("target-strategy.header",
                                      comment: "header of the strategy section -- describing the target hours"),
                    $0)
        }
    }

    func wireBaselineField() {
        baselineField.reactive.text <~ dayBaselineAdjustedToProgress.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("target-strategy.adjusted-baseline",
                                      comment: """
                                               amount of time to work per day to achieve the target time
                                               (adjusted day baseline)
                                               """),
                    $0)
        }
    }

    func wireBaselineDifferentialField() { // swiftlint:disable:this function_body_length
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
            .map { _ in NSLocalizedString("target-strategy.cannot-calculate-baseline",
                                          comment: "the adjusted day baseline could not be calculated") }

        let feasibleCaseDescriptions =
            SignalProducer.combineLatest(feasibility.skipNil(),
                                         dayBaselineDifferential.skipNil(),
                                         formattedDifferential,
                                         dayBaseline.skipNil(),
                                         dayBaseline.mapToString(timeFormatter: timeFormatter))
                .filter { (feasibility, _, _, _, _) in
                    return feasibility.isFeasible
                }.map { (_, differential, formattedDifferential, _, formattedBaseline) -> String in
                    if abs(differential) < 0.01 {
                        return String.localizedStringWithFormat(
                            NSLocalizedString("target-strategy.adusted-baseline-matches",
                                              comment: """
                                                       the adjusted baseline approximately matches the
                                                       a priori baseline
                                                       """),
                            formattedBaseline)
                    } else if differential > 0 {
                        return String.localizedStringWithFormat(
                            NSLocalizedString("target-strategy.differential.more",
                                              comment: "need to catch up to achieve the target time"),
                            formattedDifferential, formattedBaseline)
                    } else {
                        return String.localizedStringWithFormat(
                            NSLocalizedString("target-strategy.differential.less",
                                              comment: "could work less and still achieve the target time"),
                            formattedDifferential, formattedBaseline)
                    }
        }

        let unfeasibleCaseDescriptions = feasibility.skipNil().filter { $0.isUnfeasible }
            .map { _ in
                NSLocalizedString("target-strategy.unfeasible",
                                  comment: "reaching the target time is unfeasible but not impossible")
        }

        let impossibleCaseDescriptions = feasibility.skipNil().filter { $0.isImpossible }
            .map { _ in
                NSLocalizedString("target-strategy.impossible",
                                  comment: "reaching the target time is impossible")
        }

        baselineDifferentialField.reactive.stringValue <~
            SignalProducer.merge(feasibleCaseDescriptions, unfeasibleCaseDescriptions,
                                 impossibleCaseDescriptions, baselineCalculationErrors)
    }
}

// MARK: -

class TargetReachedViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = SignalProducer<TimeInterval, NoError>

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    private lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.unitsStyle = .full
        return formatter
    }()

    @IBOutlet weak var targetReachedField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        let targetTime = lastBinding.latestOutput { $0 }
        targetReachedField.reactive.text <~ targetTime.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("target-time-reached", comment: "the target time has been reached"),
                    $0)
        }
    }
}
