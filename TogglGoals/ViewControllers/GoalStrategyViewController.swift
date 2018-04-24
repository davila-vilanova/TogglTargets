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

class GoalStrategyViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        timeGoal: SignalProducer<TimeInterval, NoError>,
        dayBaseline: SignalProducer<TimeInterval?, NoError>,
        dayBaselineAdjustedToProgress: SignalProducer<TimeInterval?, NoError>,
        dayBaselineDifferential: SignalProducer<Double?, NoError>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Backing properties

    private let timeGoal = MutableProperty<TimeInterval>(0)
    private let dayBaseline = MutableProperty<TimeInterval?>(nil)
    private let dayBaselineAdjustedToProgress = MutableProperty<TimeInterval?>(nil)
    private let dayBaselineDifferential = MutableProperty<Double?>(nil)


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

    @IBOutlet weak var totalHoursStrategyLabel: NSTextField!
    @IBOutlet weak var hoursPerDayLabel: NSTextField!
    @IBOutlet weak var baselineDifferentialLabel: NSTextField!


    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        timeGoal <~ lastBinding.latestOutput { $0.timeGoal }
        dayBaseline <~ lastBinding.latestOutput { $0.dayBaseline }
        dayBaselineAdjustedToProgress <~ lastBinding.latestOutput { $0.dayBaselineAdjustedToProgress }
        dayBaselineDifferential <~ lastBinding.latestOutput { $0.dayBaselineDifferential }

        // Update total hours and hours per day with the values of the corresponding signals, formatted to a time string
        totalHoursStrategyLabel.reactive.text <~ timeGoal.producer.mapToString(timeFormatter: timeFormatter)
        hoursPerDayLabel.reactive.text <~ dayBaselineAdjustedToProgress.producer.mapToString(timeFormatter: timeFormatter)

        let formattedDifferential = dayBaselineDifferential.producer
            .map { $0?.magnitude }
            .map { (differential) -> NSNumber? in
            guard let differential = differential else { return nil }
            return NSNumber(value: differential)
            }
            .mapToNumberFormattedString(numberFormatter: percentFormatter)

        baselineDifferentialLabel.reactive.text <~
            SignalProducer.combineLatest(dayBaselineDifferential.producer,
                                         formattedDifferential,
                                         dayBaseline.producer,
                                         dayBaseline.producer.mapToString(timeFormatter: timeFormatter))
                .map { (differential, formattedDifferential, baseline, formattedBaseline) -> String in
                    guard let differential = differential,
                        baseline != nil else {
                            return "The day baseline could not be calculated"
                    }
                    let absoluteDifferential = abs(differential)

                    if absoluteDifferential < 0.01 {
                        return "That prety much matches your baseline of \(formattedBaseline)"
                    } else {
                        let adverb = differential > 0 ? "more" : "less"
                        return "That is \(formattedDifferential) \(adverb) than your baseline of \(formattedBaseline)"
                    }
        }
    }
}

// MARK: -

class GoalReachedViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = SignalProducer<TimeInterval, NoError>

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    private let timeGoal = MutableProperty<TimeInterval>(0)

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()

    @IBOutlet weak var totalHoursLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        timeGoal <~ lastBinding.latestOutput { $0 }
        totalHoursLabel.reactive.text <~ timeGoal.producer.mapToString(timeFormatter: timeFormatter)
    }
}
