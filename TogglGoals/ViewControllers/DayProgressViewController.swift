//
//  DayProgressViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class DayProgressViewController: NSViewController {

    // MARK: Exposed targets

    internal var timeWorkedToday: BindingTarget<TimeInterval> { return _timeWorkedToday.bindingTarget }
    internal var remainingTimeToDayBaseline: BindingTarget<TimeInterval?> { return _remainingTimeToDayBaseline.bindingTarget }


    // MARK: - Backing Properties

    private let _timeWorkedToday = MutableProperty<TimeInterval>(0)
    private let _remainingTimeToDayBaseline = MutableProperty<TimeInterval?>(nil)


    // MARK: - Private

    //    private var dayProgressProperties = DayProgressProperties()

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


        // Update worked and remaining time today with the values of the corresponding signals formatted to a time string
        // TODO: do not include English text directly in inline constant strings

        let isTimeRemainingMissing = _remainingTimeToDayBaseline.producer.map { $0 == nil }

        timeWorkedTodayLabel.reactive.text <~ _timeWorkedToday.producer.map { [timeFormatter] time in
            "\(timeFormatter.string(from: time) ?? "-") worked today"
        }
        timeRemainingToWorkTodayLabel.reactive.text <~ _remainingTimeToDayBaseline.producer.skipNil().map { [timeFormatter] time in
            "\(timeFormatter.string(from: time) ?? "-") left to meet your goal today"
        }

        // Show or hide time remaining and progress indicator
        isTimeRemainingMissing.observe(on: UIScheduler()).startWithValues { [timeRemainingToWorkTodayLabel, todayProgressIndicator] isTimeRemainingMissing in
            timeRemainingToWorkTodayLabel?.isHidden = isTimeRemainingMissing
            todayProgressIndicator?.isIndeterminate = isTimeRemainingMissing
        }

        // Update progress indicator
        SignalProducer.combineLatest(_timeWorkedToday.producer,
                                     _remainingTimeToDayBaseline.producer.skipNil())
            .observe(on: UIScheduler()).startWithValues { [todayProgressIndicator] (worked, remaining) in
                todayProgressIndicator?.maxValue = worked + remaining
                todayProgressIndicator?.doubleValue = worked
        }
    }
}
