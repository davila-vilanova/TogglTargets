//
//  GoalProgressViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class GoalProgressViewController: NSViewController {

    // MARK: Interface

    internal let goalProgress = MutableProperty<GoalProgress?>(nil)


    // MARK: - Private

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()


    // MARK: - Outlets

    @IBOutlet weak var totalWorkdaysLabel: NSTextField!
    @IBOutlet weak var remainingFullWorkdaysLabel: NSTextField!
    @IBOutlet weak var hoursWorkedLabel: NSTextField!
    @IBOutlet weak var hoursLeftLabel: NSTextField!

    @IBOutlet weak var workDaysProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var workHoursProgressIndicator: NSProgressIndicator!


    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        let progress = goalProgress.producer.skipNil()
        let totalWorkDays = progress.map { $0.totalWorkdays }
        let remainingWorkDays = progress.map { $0.remainingWorkdays }
        let timeGoal = progress.map { $0.timeGoal }
        let workedTime = progress.map { $0.workedTime }
        let remainingTimeToGoal = progress.map { $0.remainingTimeToGoal }

        // Update total and remaining work days with the unconverted value of the corresponding signals
        totalWorkdaysLabel.reactive.integerValue <~ totalWorkDays
        remainingFullWorkdaysLabel.reactive.integerValue <~ remainingWorkDays

        // Update hours worked and left with the value of the corresponding signals, formatted to a time string
        let formatTime = { [timeFormatter] (time: TimeInterval) -> String in
            return timeFormatter.string(from: time) ?? "-"
        }
        hoursWorkedLabel.reactive.text <~ workedTime.map(formatTime)
        hoursLeftLabel.reactive.text <~ remainingTimeToGoal.map(formatTime)

        // Progress indicators
        let intToDouble = { (integer: Int) -> Double in return Double(integer) }
        SignalProducer.combineLatest(totalWorkDays.map(intToDouble), remainingWorkDays.map(intToDouble)).skipRepeats { $0 == $1 }.producer.observe(on: UIScheduler()).startWithValues { [weak self] (total, remaining) in
            self?.workDaysProgressIndicator.maxValue = total
            // Has a hard limit (the end of the time period for which the goal is being calculated)
            self?.workDaysProgressIndicator.doubleValue = total - remaining
        }

        SignalProducer.combineLatest(timeGoal, workedTime).skipRepeats { $0 == $1 }.producer.observe(on: UIScheduler()).startWithValues { [weak self] (timeGoal, workedTime) in
            self?.workHoursProgressIndicator.maxValue = timeGoal
            // No hard limit (nothing prevents one from exceeding their time goal)
            self?.workHoursProgressIndicator.doubleValue = workedTime
        }
    }
}
