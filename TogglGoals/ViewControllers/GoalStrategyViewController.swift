//
//  GoalStrategyViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class GoalStrategyViewController: NSViewController {

    // MARK: Exposed targets

    internal var timeGoal: BindingTarget<TimeInterval> { return _timeGoal.bindingTarget }
    internal var dayBaseline: BindingTarget<TimeInterval?> { return _dayBaseline.bindingTarget }
    internal var dayBaselineAdjustedToProgress: BindingTarget<TimeInterval?> { return _dayBaselineAdjustedToProgress.bindingTarget }
    internal var dayBaselineDifferential: BindingTarget<Double?> { return _dayBaselineDifferential.bindingTarget }


    // MARK: - Properties

    private let _timeGoal = MutableProperty<TimeInterval>(0)
    private let _dayBaseline = MutableProperty<TimeInterval?>(nil)
    private let _dayBaselineAdjustedToProgress = MutableProperty<TimeInterval?>(nil)
    private let _dayBaselineDifferential = MutableProperty<Double?>(nil)


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

        // Update total hours and hours per day with the values of the corresponding signals, formatted to a time string
        totalHoursStrategyLabel.reactive.text <~ _timeGoal.producer.mapToString(timeFormatter: timeFormatter)
        hoursPerDayLabel.reactive.text <~ _dayBaselineAdjustedToProgress.producer.mapToString(timeFormatter: timeFormatter)

        let formattedDifferential = _dayBaselineDifferential.producer.map { (differential) -> NSNumber? in
            guard let differential = differential else { return nil }
            return NSNumber(value: differential)
            }.mapToNumberFormattedString(numberFormatter: percentFormatter)

        baselineDifferentialLabel.reactive.text <~
            SignalProducer.combineLatest(_dayBaselineDifferential.producer,
                                         formattedDifferential,
                                         _dayBaseline.producer,
                                         _dayBaseline.producer.mapToString(timeFormatter: timeFormatter))
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

