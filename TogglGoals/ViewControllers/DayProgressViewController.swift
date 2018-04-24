//
//  DayProgressViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class DayProgressViewController: NSViewController, BindingTargetProvider {

    // MARK: Interface

    internal typealias Interface = (timeWorkedToday: SignalProducer<TimeInterval, NoError>,
        remainingTimeToDayBaseline: SignalProducer<TimeInterval?, NoError>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Backing Properties

    private let timeWorkedToday = MutableProperty<TimeInterval>(0)
    private let remainingTimeToDayBaseline = MutableProperty<TimeInterval?>(nil)


    // MARK: - Private

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()


    // MARK: - Outlets

    @IBOutlet weak var dayProgressBox: NSBox!
    @IBOutlet weak var todayProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var timeWorkedTodayLabel: NSTextField!
    @IBOutlet weak var timeRemainingToWorkTodayLabel: NSTextField!


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        timeWorkedToday <~ lastBinding.latestOutput { $0.timeWorkedToday }
        remainingTimeToDayBaseline <~ lastBinding.latestOutput { $0.remainingTimeToDayBaseline }

        // Update worked and remaining time today with the values of the corresponding signals formatted to a time string
        // TODO: do not include English text directly in inline constant strings

        let isTimeRemainingMissing = remainingTimeToDayBaseline.producer.map { $0 == nil }

        timeWorkedTodayLabel.reactive.text <~ timeWorkedToday.producer.map { [timeFormatter] time in
            "\(timeFormatter.string(from: time) ?? "-") worked today"
        }
        timeRemainingToWorkTodayLabel.reactive.text <~ remainingTimeToDayBaseline.producer.skipNil().map { [timeFormatter] time in
            "\(timeFormatter.string(from: time) ?? "-") left to meet your goal today"
        }

        // Show or hide time remaining and progress indicator
        isTimeRemainingMissing.observe(on: UIScheduler()).startWithValues { [timeRemainingToWorkTodayLabel, todayProgressIndicator] isTimeRemainingMissing in
            timeRemainingToWorkTodayLabel?.isHidden = isTimeRemainingMissing
            todayProgressIndicator?.isIndeterminate = isTimeRemainingMissing
        }

        // Update progress indicator
        SignalProducer.combineLatest(timeWorkedToday.producer,
                                     remainingTimeToDayBaseline.producer.skipNil())
            .observe(on: UIScheduler()).startWithValues { [todayProgressIndicator] (worked, remaining) in
                todayProgressIndicator?.maxValue = worked + remaining
                todayProgressIndicator?.doubleValue = worked
        }
    }
}
