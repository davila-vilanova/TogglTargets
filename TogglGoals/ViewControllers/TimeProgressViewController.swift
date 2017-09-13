//
//  TimeProgressViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class TimeProgressViewController: NSViewController {

    // MARK: Interface

    internal let timeGoal = MutableProperty<TimeInterval?>(nil)
    internal let totalWorkDays = MutableProperty<Int?>(nil)
    internal let remainingWorkDays = MutableProperty<Int?>(nil)
    internal let workedTime = MutableProperty<TimeInterval?>(nil)
    internal let remainingTimeToGoal = MutableProperty<TimeInterval?>(nil)


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

        // Update total and remaining work days with the unconverted value of the corresponding signals
        totalWorkdaysLabel.reactive.integerValue <~ totalWorkDays.producer.skipNil()
        remainingFullWorkdaysLabel.reactive.integerValue <~ remainingWorkDays.producer.skipNil()

        // Update hours worked and left with the value of the corresponding signals, formatted to a time string
        let formatTime = { [timeFormatter] (time: TimeInterval) -> String in
            return timeFormatter.string(from: time) ?? "-"
        }
        hoursWorkedLabel.reactive.text <~ workedTime.producer.skipNil().map(formatTime)
        hoursLeftLabel.reactive.text <~ remainingTimeToGoal.producer.skipNil().map(formatTime)

        // Progress indicators
        let intToDouble = { (integer: Int) -> Double in return Double(integer) }
        SignalProducer.combineLatest(totalWorkDays.producer.skipNil().map(intToDouble),
                                     remainingWorkDays.producer.skipNil().map(intToDouble))
            .skipRepeats { $0 == $1 }
            .observe(on: UIScheduler())
            .startWithValues {
                [unowned self] (total, remaining) in
                self.workDaysProgressIndicator.maxValue = total
                // Has a hard limit (the end of the time period for which the goal is being calculated)
                self.workDaysProgressIndicator.doubleValue = total - remaining
        }

        SignalProducer.combineLatest(timeGoal.producer.skipNil(),
                                     workedTime.producer.skipNil())
            .skipRepeats { $0 == $1 }
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] (timeGoal, workedTime) in
                self.workHoursProgressIndicator.maxValue = timeGoal
                // No hard limit (nothing prevents one from exceeding their time goal)
                self.workHoursProgressIndicator.doubleValue = workedTime
        }
    }
}
