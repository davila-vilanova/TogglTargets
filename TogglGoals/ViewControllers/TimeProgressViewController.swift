//
//  TimeProgressViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class TimeProgressViewController: NSViewController {

    // MARK: Interface

    internal typealias Interface = (timeGoal: SignalProducer<TimeInterval, NoError>,
        totalWorkDays: SignalProducer<Int?, NoError>,
        remainingWorkDays: SignalProducer<Int?, NoError>,
        workedTime: SignalProducer<TimeInterval, NoError>,
        remainingTimeToGoal: SignalProducer<TimeInterval, NoError>,
        strategyStartsToday: SignalProducer<Bool, NoError>)

    private var _interface = MutableProperty<Interface?>(nil)
    internal var interface: BindingTarget<Interface?> { return _interface.bindingTarget }

    private func connectInterface() {
        timeGoal <~ _interface.latest { $0.timeGoal }
        totalWorkDays <~ _interface.latest { $0.totalWorkDays }
        remainingWorkDays <~ _interface.latest { $0.remainingWorkDays }
        workedTime <~ _interface.latest { $0.workedTime }
        remainingTimeToGoal <~ _interface.latest { $0.remainingTimeToGoal }
        strategyStartsToday <~ _interface.latest { $0.strategyStartsToday }
    }


    // MARK: - Backing properties

    private let timeGoal = MutableProperty<TimeInterval>(0)
    private let totalWorkDays = MutableProperty<Int?>(nil)
    private let remainingWorkDays = MutableProperty<Int?>(nil)
    private let workedTime = MutableProperty<TimeInterval>(0)
    private let remainingTimeToGoal = MutableProperty<TimeInterval>(0)
    private let strategyStartsToday = MutableProperty<Bool?>(nil)


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
            totalWorkdaysLabel.reactive.stringValue <~ totalWorkDays.producer.mapToString()
        }
    }
    @IBOutlet weak var remainingWorkdaysAmountLabel: NSTextField! {
        didSet {
            remainingWorkdaysAmountLabel.reactive.stringValue <~ remainingWorkDays.producer.mapToString()
        }
    }
    @IBOutlet weak var remainingWorkdaysTextLabel: NSTextField! {
        didSet {
            remainingWorkdaysTextLabel.reactive.text <~ strategyStartsToday.producer.skipNil()
                .map { (isTodayIncluded) -> String in
                    return isTodayIncluded ? "work days left (including today)" : "work days left from tomorrow"
            }
        }
    }
    @IBOutlet weak var hoursWorkedAmountLabel: NSTextField! {
        didSet {
            hoursWorkedAmountLabel.reactive.text <~ workedTime.producer.mapToString(timeFormatter: timeFormatter)
        }
    }
    @IBOutlet weak var hoursWorkedTextLabel: NSTextField! {
        didSet {
            hoursWorkedTextLabel.reactive.text <~ strategyStartsToday.producer.skipNil()
                .map { (strategyStartsToday) -> String in
                    return strategyStartsToday ? "worked (not including today)" : "worked (including today)"
            }
        }
    }
    @IBOutlet weak var hoursLeftAmountLabel: NSTextField! {
        didSet {
            hoursLeftAmountLabel.reactive.text <~ remainingTimeToGoal.producer.mapToString(timeFormatter: timeFormatter)
        }
    }

    @IBOutlet weak var workDaysProgressIndicator: NSProgressIndicator! {
        didSet {
            SignalProducer.combineLatest(totalWorkDays.producer.map(intToDouble),
                                         remainingWorkDays.producer.map(intToDouble))
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
            SignalProducer.combineLatest(timeGoal.producer, workedTime.producer)
                .skipRepeats { $0 == $1 }
                .observe(on: UIScheduler())
                .startWithValues { [indicator = workHoursProgressIndicator] (timeGoal, workedTime) in
                    indicator!.maxValue = timeGoal
                    // No hard limit (nothing prevents one from exceeding their time goal)
                    indicator!.doubleValue = workedTime
            }
        }
    }

    // MARK: -

    override func viewDidLoad() {
        connectInterface()
    }
}

fileprivate let intToDouble = { (integerOrNil: Int?) -> Double? in
    guard let integer = integerOrNil else {
        return nil
    }
    return Double(integer)
}
