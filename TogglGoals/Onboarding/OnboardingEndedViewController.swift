//
//  OnboardingEndedViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 09.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class OnboardingEndedViewController: NSViewController {

    @IBOutlet weak var closeCountdownIndicator: NSProgressIndicator!

    var close: SignalProducer<Void, NoError> {
        return _close.producer.skipNil()
    }

    private let _close = MutableProperty<Void?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        let progressSource = MutableProperty(0.0)
        let progressTarget: BindingTarget<Double> = closeCountdownIndicator.reactive.makeBindingTarget {
            $0.doubleValue = $1
        }
        progressTarget <~ progressSource

        reactive.lifetime.observeEnded {
            _ = progressSource
        }

        let delayScheduler = QueueScheduler()
        let maxProgress = 100.0
        let totalDurationUntilClose: TimeInterval = 3.0
        let period: TimeInterval = 0.1
        let stepCount = ceil(totalDurationUntilClose / period)
        let stepIncrement = maxProgress / Double(stepCount)
        let maxProgressReached = progressSource.producer.filter { $0 >= maxProgress }.map { _ in () }
        let timer = SignalProducer.timer(interval: DispatchTimeInterval.milliseconds(Int(period * 1000)), on: delayScheduler)
            .map { _ in () }.take(until: maxProgressReached)
        progressSource <~ progressSource.producer.sample(on: timer).map { $0 + stepIncrement }
        _close <~ maxProgressReached
    }
    
}
