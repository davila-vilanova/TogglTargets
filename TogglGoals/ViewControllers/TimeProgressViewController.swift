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
    internal var strategyStartsToday: BindingTarget<Bool> { return _strategyStartsToday.deoptionalizedBindingTarget }


    // MARK: - Backing properties

    private let _timeGoal = MutableProperty<TimeInterval>(0)
    private let _totalWorkDays = MutableProperty<Int?>(nil)
    private let _remainingWorkDays = MutableProperty<Int?>(nil)
    private let _workedTime = MutableProperty<TimeInterval>(0)
    private let _remainingTimeToGoal = MutableProperty<TimeInterval>(0)
    private let _strategyStartsToday = MutableProperty<Bool?>(nil)


    // MARK: - Formatter

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()


    // MARK: - Outlets

    @IBOutlet weak var totalWorkdaysLabel: NSTextField! {
        didSet {
            totalWorkdaysLabel.reactive.stringValue <~ _totalWorkDays.producer.mapToString()
        }
    }
    @IBOutlet weak var remainingWorkdaysAmountLabel: NSTextField! {
        didSet {
            remainingWorkdaysAmountLabel.reactive.stringValue <~ _remainingWorkDays.producer.mapToString()
        }
    }
    @IBOutlet weak var remainingWorkdaysTextLabel: NSTextField! {
        didSet {
            remainingWorkdaysTextLabel.reactive.text <~ _strategyStartsToday.producer.skipNil()
                .map { (isTodayIncluded) -> String in
                    return isTodayIncluded ? "work days left (including today)" : "work days left from tomorrow"
            }
        }
    }
    @IBOutlet weak var hoursWorkedAmountLabel: NSTextField! {
        didSet {
            hoursWorkedAmountLabel.reactive.text <~ _workedTime.producer.mapToString(timeFormatter: timeFormatter)
        }
    }
    @IBOutlet weak var hoursWorkedTextLabel: NSTextField! {
        didSet {
            hoursWorkedTextLabel.reactive.text <~ _strategyStartsToday.producer.skipNil()
                .map { (strategyStartsToday) -> String in
                    return strategyStartsToday ? "worked (not including today)" : "worked (including today)"
            }
        }
    }
    @IBOutlet weak var hoursLeftAmountLabel: NSTextField! {
        didSet {
            hoursLeftAmountLabel.reactive.text <~ _remainingTimeToGoal.producer.mapToString(timeFormatter: timeFormatter)
        }
    }

    @IBOutlet weak var workDaysProgressIndicator: NSProgressIndicator! {
        didSet {
            SignalProducer.combineLatest(_totalWorkDays.producer.map(intToDouble),
                                         _remainingWorkDays.producer.map(intToDouble))
                .observe(on: UIScheduler())
                .startWithValues { [indicator = workDaysProgressIndicator] (totalOrNil, remainingOrNil) in
                    let total = totalOrNil ?? 0.0
                    let remaining = remainingOrNil ?? 0.0
                    indicator!.maxValue = total
                    // Has a hard limit (the end of the time period for which the goal is being calculated)
                    indicator!.doubleValue = total - remaining
            }
        }
    }
    @IBOutlet weak var workHoursProgressIndicator: NSProgressIndicator! {
        didSet {
            SignalProducer.combineLatest(_timeGoal.producer, _workedTime.producer)
                .skipRepeats { $0 == $1 }
                .observe(on: UIScheduler())
                .startWithValues { [indicator = workHoursProgressIndicator] (timeGoal, workedTime) in
                    indicator!.maxValue = timeGoal
                    // No hard limit (nothing prevents one from exceeding their time goal)
                    indicator!.doubleValue = workedTime
            }
        }
    }

    private let intToDouble = { (integerOrNil: Int?) -> Double? in
        guard let integer = integerOrNil else {
            return nil
        }
        return Double(integer)
    }
}
