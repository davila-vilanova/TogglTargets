//
//  DayProgressViewController.swift
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
import Result
import ReactiveSwift
import ReactiveCocoa

class DayProgressViewController: NSViewController, BindingTargetProvider, OnboardingTargetViewsProvider {

    // MARK: Interface

    internal typealias Interface = (timeWorkedToday: SignalProducer<TimeInterval, NoError>,
        remainingTimeToDayBaseline: SignalProducer<TimeInterval?, NoError>,
        feasibility: SignalProducer<TargetFeasibility, NoError>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Private

    private lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.unitsStyle = .full
        return formatter
    }()

    // MARK: - Outlets

    @IBOutlet weak var dayProgressBox: NSBox!
    @IBOutlet weak var todayProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var timeWorkedTodayLabel: NSTextField!
    @IBOutlet weak var timeRemainingToWorkTodayLabel: NSTextField!

    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        let timeWorkedToday = lastBinding.latestOutput { $0.timeWorkedToday }
        let remainingTimeToDayBaseline = lastBinding.latestOutput { $0.remainingTimeToDayBaseline }

        // Update worked and remaining time today with the values of the corresponding signals
        // formatted to a time string

        timeWorkedTodayLabel.reactive.text <~ timeWorkedToday.mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("day-progress.worked-today", comment: "amount of time worked today"), $0)
        }

        timeRemainingToWorkTodayLabel.reactive.text <~ remainingTimeToDayBaseline
            .mapToString(timeFormatter: timeFormatter)
            .map {
                String.localizedStringWithFormat(
                    NSLocalizedString("day-progress.to-work-today",
                                      comment: "amount of time left to meet daily target"), $0)
        }

        // Update progress indicator
        todayProgressIndicator.reactive.makeBindingTarget { (progress, times) in
            let (worked, remaining) = times
            progress.maxValue = worked + remaining
            progress.doubleValue = worked
            } <~ SignalProducer.combineLatest(timeWorkedToday.producer, remainingTimeToDayBaseline.skipNil())

        // Show or hide time remaining and progress indicator
        let isTimeRemainingMissing = remainingTimeToDayBaseline.map { $0 == nil }
        let isMeetingTargetImpossible = lastBinding.latestOutput { $0.feasibility }.map { $0.isImpossible }
        let hide = isTimeRemainingMissing.or(isMeetingTargetImpossible)
        timeRemainingToWorkTodayLabel.reactive.makeBindingTarget { $0.isHidden = $1 } <~ hide
        todayProgressIndicator.reactive.makeBindingTarget { $0.isIndeterminate = $1 } <~ hide
    }

    // MARK: - Onboarding

    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, NoError>] {
        let dayProgressView = viewDidLoadProducer
            .map { [unowned self] _ in self.view }
            .concat(SignalProducer.never)
        return [.seeDayProgress: dayProgressView]
    }
}
