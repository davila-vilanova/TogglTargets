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

class TimeProgressViewController: NSViewController, BindingTargetProvider, TimeProgressViewProviding {

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
            workdaysInPeriodField.reactive.stringValue <~ totalWorkDays.producer.mapToNonNil().map {
                String.localizedStringWithFormat(
                    NSLocalizedString("time-progress.workdays.total", comment: "total amount of workdays in current period"),
                    $0)
            }
        }
    }

    @IBOutlet weak var remainingWorkdaysField: NSTextField! {
        didSet {
            let formattedRemainingWorkdays = remainingWorkDays.producer.mapToNonNil()

            let formattedIncludingToday = formattedRemainingWorkdays.throttle(while: strategyStartsToday.negate(), on: UIScheduler())
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.workdays.left.including-today", comment: "remaining workdays in current period, including today"),
                        $0)

            }
            let formattedExcludingToday = formattedRemainingWorkdays.throttle(while: strategyStartsToday, on: UIScheduler())
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.workdays.left.excluding-today", comment: "remaining workdays in current period, not including today"),
                        $0)
            }

            remainingWorkdaysField.reactive.stringValue <~ SignalProducer.merge(formattedIncludingToday, formattedExcludingToday)
        }
    }

    @IBOutlet weak var workedHoursField: NSTextField! {
        didSet {
            let formattedTime = workedTime.producer.mapToString(timeFormatter: timeFormatter)
            let noReportAvailableText = SignalProducer(value: NSLocalizedString("time-progress.report.no-data", comment: "message to show in the time progress view controller when there is no report data yet"))

            let formattedIncludingToday = formattedTime.throttle(while: strategyStartsToday.negate(), on: UIScheduler())
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.report.worked-time.including-today", comment: "worked time including today"),
                        $0)
            }
            let formattedExcludingToday = formattedTime.throttle(while: strategyStartsToday, on: UIScheduler())
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.report.worked-time.excluding-today", comment: "worked time not including today"),
                        $0)

            }

            let formattedText = SignalProducer.merge(formattedIncludingToday, formattedExcludingToday)

            workedHoursField.reactive.text <~
                SignalProducer.merge(formattedText.throttle(while: reportAvailable.negate(), on: UIScheduler()),
                                     noReportAvailableText.sample(on: reportAvailable.producer.negate().filter { $0 }.map { _ in () }))
        }
    }

    @IBOutlet weak var remainingHoursField: NSTextField! {
        didSet {
            remainingHoursField.reactive.text <~ remainingTimeToGoal.producer.mapToString(timeFormatter: timeFormatter)
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.report.goal.remaining", comment: "amount of time remaining to achieve the goal"),
                        $0)
            }
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
    
    
    // MARK: - Onboarding
    
    var timeProgressView: SignalProducer<NSView, NoError> {
        return viewDidLoadProducer
            .map { [unowned self] _ in self.view }
            .concat(SignalProducer.never)
    }
}

fileprivate let intToDouble = { (integerOrNil: Int?) -> Double? in
    guard let integer = integerOrNil else {
        return nil
    }
    return Double(integer)
}
