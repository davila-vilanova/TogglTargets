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

class TimeProgressViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (
        timeGoal: SignalProducer<TimeInterval, NoError>,
        totalWorkDays: SignalProducer<Int?, NoError>,
        remainingWorkDays: SignalProducer<Int?, NoError>,
        reportAvailable: SignalProducer<Bool, NoError>,
        workedTime: SignalProducer<TimeInterval, NoError>,
        remainingTimeToGoal: SignalProducer<TimeInterval, NoError>,
        strategyStartsToday: SignalProducer<Bool, NoError>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Backing properties

    private let timeGoal = MutableProperty<TimeInterval>(0)
    private let totalWorkDays = MutableProperty<Int?>(nil)
    private let remainingWorkDays = MutableProperty<Int?>(nil)
    private let reportAvailable = MutableProperty<Bool>(false)
    private let workedTime = MutableProperty<TimeInterval>(0)
    private let remainingTimeToGoal = MutableProperty<TimeInterval>(0)
    private let strategyStartsToday = MutableProperty<Bool>(false)


    // MARK: - Formatter

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()


    // MARK: - Outlets

    @IBOutlet weak var workdaysInPeriodField: NSTextField! {
        didSet {
            workdaysInPeriodField.reactive.stringValue <~ totalWorkDays.producer.mapToString().map { "this period has \($0) work days" }
        }
    }

    @IBOutlet weak var remainingWorkdaysField: NSTextField! {
        didSet {
            let formattedRemainingWorkdays = remainingWorkDays.producer.mapToString()

            let formattedIncludingToday = formattedRemainingWorkdays.throttle(while: strategyStartsToday.negate(), on: UIScheduler())
                .map { "\($0) work days left (including today)" }
            let formattedExcludingToday = formattedRemainingWorkdays.throttle(while: strategyStartsToday, on: UIScheduler())
                .map { "\($0) work days left (not including today)" }

            remainingWorkdaysField.reactive.stringValue <~ SignalProducer.merge(formattedIncludingToday, formattedExcludingToday)
        }
    }

    @IBOutlet weak var workedHoursField: NSTextField! {
        didSet {
            let formattedTime = workedTime.producer.mapToString(timeFormatter: timeFormatter)
            let noReportAvailableText = SignalProducer(value: "no report data")

            let formattedIncludingToday = formattedTime.throttle(while: strategyStartsToday.negate(), on: UIScheduler())
                .map { "\($0) worked (including today)" }
            let formattedExcludingToday = formattedTime.throttle(while: strategyStartsToday, on: UIScheduler())
                .map { "\($0) worked (not including today)" }

            let formattedText = SignalProducer.merge(formattedIncludingToday, formattedExcludingToday)

            workedHoursField.reactive.text <~
                SignalProducer.merge(formattedText.throttle(while: reportAvailable.negate(), on: UIScheduler()),
                                     noReportAvailableText.sample(on: reportAvailable.producer.negate().filter { $0 }.map { _ in () }))
        }
    }

    @IBOutlet weak var remainingHoursField: NSTextField! {
        didSet {
            remainingHoursField.reactive.text <~ remainingTimeToGoal.producer.mapToString(timeFormatter: timeFormatter)
                .map { "\($0) remaining" }
            remainingHoursField.reactive.makeBindingTarget { $0.isHidden = $1 } <~ reportAvailable.negate()
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
            workHoursProgressIndicator.reactive.makeBindingTarget { $0.animator().isHidden = $1 } <~ reportAvailable.negate()
        }
    }

    // MARK: -

    override func viewDidLoad() {
        timeGoal <~ lastBinding.latestOutput { $0.timeGoal }
        totalWorkDays <~ lastBinding.latestOutput { $0.totalWorkDays }
        remainingWorkDays <~ lastBinding.latestOutput { $0.remainingWorkDays }
        reportAvailable <~ lastBinding.latestOutput { $0.reportAvailable }
        workedTime <~ lastBinding.latestOutput { $0.workedTime }
        remainingTimeToGoal <~ lastBinding.latestOutput { $0.remainingTimeToGoal }
        strategyStartsToday <~ lastBinding.latestOutput { $0.strategyStartsToday }
    }
}

fileprivate let intToDouble = { (integerOrNil: Int?) -> Double? in
    guard let integer = integerOrNil else {
        return nil
    }
    return Double(integer)
}
