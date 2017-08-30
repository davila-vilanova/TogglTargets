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

    // MARK: Interface

    internal var goalStrategy = MutableProperty<GoalStrategy?>(nil)


    // MARK: - Private

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
        // TODO: Extension on TimeFormatter
        let formatTime = { [timeFormatter] (time: TimeInterval) -> String in
            return timeFormatter.string(from: time) ?? "-"
        }

        let strategies = goalStrategy.producer.skipNil()
        let timeGoals = strategies.map { $0.timeGoal }
        let adjustedBaselines = strategies.map { $0.dayBaselineAdjustedToProgress }
        let baselineDifferentials = strategies.map { $0.dayBaselineDifferential }
        let baselines = strategies.map { $0.dayBaseline }

        totalHoursStrategyLabel.reactive.text <~ timeGoals.map(formatTime)
        hoursPerDayLabel.reactive.text <~ adjustedBaselines.map(formatTime)

        baselineDifferentialLabel.reactive.text <~ SignalProducer.combineLatest(baselineDifferentials, baselines).skipRepeats { $1 == $0 }.map { [percentFormatter, timeFormatter] (differential, baseline) -> String in
            let formattedBaseline = timeFormatter.string(from: baseline) ?? "-"
            let absoluteDifferential = abs(differential)

            if absoluteDifferential < 0.01 {
                return "That prety much matches your baseline of \(formattedBaseline)"
            } else {
                let formattedDifferential = percentFormatter.string(from: NSNumber(value: absoluteDifferential)) ?? "-"
                let adverb = differential > 0 ? "more" : "less"
                return "That is \(formattedDifferential) \(adverb) than your baseline of \(formattedBaseline)"
            }
        }
    }
}
