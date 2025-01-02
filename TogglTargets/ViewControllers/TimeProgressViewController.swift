//
//  TimeProgressViewController.swift
//  TogglTargets
//
//  Created by David Davila on 27.05.17.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class TimeProgressViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: Interface

    internal typealias Interface = (
        targetTime: SignalProducer<TimeInterval, Never>,
        totalWorkDays: SignalProducer<Int, Never>,
        remainingWorkDays: SignalProducer<Int, Never>,
        reportAvailable: SignalProducer<Bool, Never>,
        workedTime: SignalProducer<TimeInterval, Never>,
        remainingTimeToTarget: SignalProducer<TimeInterval, Never>,
        strategyStartsToday: SignalProducer<Bool, Never>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Backing properties

    private let targetTime = MutableProperty<TimeInterval>(0)
    private let totalWorkDays = MutableProperty<Int?>(nil)
    private let remainingWorkDays = MutableProperty<Int?>(nil)
    private let reportAvailable = MutableProperty<Bool>(false)
    private let workedTime = MutableProperty<TimeInterval>(0)
    private let remainingTimeToTarget = MutableProperty<TimeInterval>(0)
    private let strategyStartsToday = MutableProperty<Bool>(false)

    // MARK: - Formatter

    private lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.unitsStyle = .full
        return formatter
    }()

    // MARK: - Outlets

    @IBOutlet weak var workdaysInPeriodField: NSTextField! {
        didSet {
            workdaysInPeriodField.reactive.stringValue <~ totalWorkDays.producer.skipNil().map {
                String.localizedStringWithFormat(
                    NSLocalizedString("time-progress.workdays.total",
                                      comment: "total amount of workdays in current period"),
                    $0)
            }
        }
    }

    @IBOutlet weak var remainingWorkdaysField: NSTextField! {
        didSet {
            let formattedRemainingWorkdays = remainingWorkDays.producer.skipNil()

            let formattedIncludingToday = formattedRemainingWorkdays.throttle(while: strategyStartsToday.negate(),
                                                                              on: UIScheduler())
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.workdays.left.including-today",
                                          comment: "remaining workdays in current period, including today"),
                        $0)

            }
            let formattedExcludingToday = formattedRemainingWorkdays
                .throttle(while: strategyStartsToday, on: UIScheduler())
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.workdays.left.excluding-today",
                                          comment: "remaining workdays in current period, not including today"),
                        $0)
            }

            remainingWorkdaysField.reactive.stringValue <~ SignalProducer.merge(formattedIncludingToday,
                                                                                formattedExcludingToday)
        }
    }

    @IBOutlet weak var workedHoursField: NSTextField! {
        didSet {
            let formattedTime = workedTime.producer.mapToString(timeFormatter: timeFormatter)
            let noReportAvailableText =
                SignalProducer(value:
                    NSLocalizedString(
                        "time-progress.report.no-data", // swiftlint:disable:next line_length
                        comment: "message to show in the time progress view controller when there is no report data yet"))

            let formattedIncludingToday = formattedTime.throttle(while: strategyStartsToday.negate(), on: UIScheduler())
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.report.worked-time.including-today",
                                          comment: "worked time including today"),
                        $0)
            }
            let formattedExcludingToday = formattedTime.throttle(while: strategyStartsToday, on: UIScheduler())
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.report.worked-time.excluding-today",
                                          comment: "worked time not including today"),
                        $0)

            }

            let formattedText = SignalProducer.merge(formattedIncludingToday, formattedExcludingToday)

            workedHoursField.reactive.text <~
                SignalProducer.merge(formattedText.throttle(while: reportAvailable.negate(), on: UIScheduler()),
                                     noReportAvailableText.sample(on: reportAvailable.producer.negate().filter { $0 }
                                        .map { _ in () }))
        }
    }

    @IBOutlet weak var remainingHoursField: NSTextField! {
        didSet {
            remainingHoursField.reactive.text <~ remainingTimeToTarget.producer
                .mapToString(timeFormatter: timeFormatter)
                .map {
                    String.localizedStringWithFormat(
                        NSLocalizedString("time-progress.report.target-time.remaining",
                                          comment: "amount of time remaining to achieve the target time"),
                        $0)
            }
            remainingHoursField.reactive.makeBindingTarget { $0.isHidden = $1 } <~ reportAvailable.negate()
        }
    }

    @IBOutlet weak var workDaysProgressIndicator: NSProgressIndicator! {
        didSet {
            SignalProducer.combineLatest(totalWorkDays.producer.skipNil().map(Double.init),
                                         remainingWorkDays.producer.skipNil().map(Double.init))
                .observe(on: UIScheduler())
                .startWithValues { [indicator = workDaysProgressIndicator] total, remaining in
                    indicator!.maxValue = total
                    // Has a hard limit (the end of the time period for which the target is being calculated)
                    indicator!.doubleValue = total - remaining
            }
        }
    }

    @IBOutlet weak var workHoursProgressIndicator: NSProgressIndicator! {
        didSet {
            SignalProducer.combineLatest(targetTime.producer, workedTime.producer)
                .skipRepeats { $0 == $1 }
                .observe(on: UIScheduler())
                .startWithValues { [indicator = workHoursProgressIndicator] (targetTime, workedTime) in
                    indicator!.maxValue = targetTime
                    // No hard limit (nothing prevents one from exceeding their time target)
                    indicator!.doubleValue = workedTime
            }
            workHoursProgressIndicator.reactive.makeBindingTarget { $0.animator().isHidden = $1 }
                <~ reportAvailable.negate()
        }
    }

    // MARK: -

    override func viewDidLoad() {
        targetTime <~ lastBinding.latestOutput { $0.targetTime }
        totalWorkDays <~ lastBinding.latestOutput { $0.totalWorkDays }
        remainingWorkDays <~ lastBinding.latestOutput { $0.remainingWorkDays }
        reportAvailable <~ lastBinding.latestOutput { $0.reportAvailable }
        workedTime <~ lastBinding.latestOutput { $0.workedTime }
        remainingTimeToTarget <~ lastBinding.latestOutput { $0.remainingTimeToTarget }
        strategyStartsToday <~ lastBinding.latestOutput { $0.strategyStartsToday }
    }

    // MARK: - Onboarding

    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, Never>] {
        let timeProgressView = viewDidLoadProducer
            .map { [unowned self] _ in self.view }
            .concat(SignalProducer.never)

        return [.seeTimeProgress: timeProgressView]
    }
}
