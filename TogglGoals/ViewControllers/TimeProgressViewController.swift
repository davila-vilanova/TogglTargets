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

    // MARK: Exposed targets

    internal var timeGoal: BindingTarget<TimeInterval> { return _timeGoal.bindingTarget }
    internal var totalWorkDays: BindingTarget<Int?> { return _totalWorkDays.bindingTarget }
    internal var remainingWorkDays: BindingTarget<Int?> { return _remainingWorkDays.bindingTarget }
    internal var workedTime: BindingTarget<TimeInterval> { return _workedTime.bindingTarget }
    internal var remainingTimeToGoal: BindingTarget<TimeInterval> { return _remainingTimeToGoal.bindingTarget }


    // MARK: - Backing properties

    private let _timeGoal = MutableProperty<TimeInterval>(0)
    private let _totalWorkDays = MutableProperty<Int?>(nil)
    private let _remainingWorkDays = MutableProperty<Int?>(nil)
    private let _workedTime = MutableProperty<TimeInterval>(0)
    private let _remainingTimeToGoal = MutableProperty<TimeInterval>(0)


    // MARK: - Formatter

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
        totalWorkdaysLabel.reactive.stringValue <~ _totalWorkDays.producer.mapToString()
        remainingFullWorkdaysLabel.reactive.stringValue <~ _remainingWorkDays.producer.mapToString()

        // Update hours worked and left with the value of the corresponding signals, formatted to a time string
        hoursWorkedLabel.reactive.text <~ _workedTime.producer.mapToString(timeFormatter: timeFormatter)
        hoursLeftLabel.reactive.text <~ _remainingTimeToGoal.producer.mapToString(timeFormatter: timeFormatter)

        // Progress indicators
        let intToDouble = { (integerOrNil: Int?) -> Double? in
            guard let integer = integerOrNil else {
                return nil
            }
            return Double(integer)
        }

        SignalProducer.combineLatest(_totalWorkDays.producer.map(intToDouble),
                                     _remainingWorkDays.producer.map(intToDouble))
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] (totalOrNil, remainingOrNil) in
                let total = totalOrNil ?? 0.0
                let remaining = remainingOrNil ?? 0.0
                self.workDaysProgressIndicator.maxValue = total
                // Has a hard limit (the end of the time period for which the goal is being calculated)
                self.workDaysProgressIndicator.doubleValue = total - remaining
        }

        SignalProducer.combineLatest(_timeGoal.producer, _workedTime.producer)
            .skipRepeats { $0 == $1 }
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] (timeGoal, workedTime) in
                self.workHoursProgressIndicator.maxValue = timeGoal
                // No hard limit (nothing prevents one from exceeding their time goal)
                self.workHoursProgressIndicator.doubleValue = workedTime
        }
    }
}
