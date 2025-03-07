//
//  PreferencesViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
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

class PreferencesViewController: NSTabViewController, BindingTargetProvider {
    internal enum Section {
        case account
        case timePeriods
    }
    // MARK: - Interface

    internal typealias Interface = (
        displaySection: SignalProducer<Section?, Never>,
        existingCredential: SignalProducer<TogglAPITokenCredential?, Never>,
        profile: SignalProducer<Profile, Never>,
        apiAccessError: SignalProducer<APIAccessError, Never>,
        resolvedCredential: BindingTarget<TogglAPITokenCredential?>,
        testURLSessionAction: RetrieveProfileNetworkAction,
        existingTimeTargetPeriodPreference: SignalProducer<PeriodPreference, Never>,
        calendar: SignalProducer<Calendar, Never>,
        currentDate: SignalProducer<Date, Never>,
        updatedTimeTargetPeriodPreference: BindingTarget<PeriodPreference>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Contained view controllers

    private enum ContainedControllerType: Int {
        case account = 0
        case timePeriods = 1

        static func from(_ controller: NSViewController) -> ContainedControllerType? {
            if controller as? AccountViewController != nil {
                return .account
            } else if controller as? TimePeriodPreferencesViewController != nil {
                return .timePeriods
            } else {
                return nil
            }
        }
    }

    private var connectedControllerTypes = Set<ContainedControllerType>()

    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)

        guard let controller = tabViewItem?.viewController,
            let type = ContainedControllerType.from(controller),
            !connectedControllerTypes.contains(type) else {
                return
        }

        connectedControllerTypes.insert(type)

        let validBindings = lastBinding.producer.skipNil()
        if let account = controller as? AccountViewController {
            account <~ validBindings.map {
                ($0.existingCredential, $0.profile, $0.apiAccessError, $0.resolvedCredential, $0.testURLSessionAction)
            }
        } else if let timePeriods = controller as? TimePeriodPreferencesViewController {
            timePeriods <~ validBindings.map {
                ($0.calendar, $0.currentDate, $0.existingTimeTargetPeriodPreference,
                 $0.updatedTimeTargetPeriodPreference)
            }
        }
    }

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        self.reactive.makeBindingTarget(on: UIScheduler()) {
            $0.selectedTabViewItemIndex = $1
            } <~ lastBinding.latestOutput { $0.displaySection }
                .skipNil().map { section -> ContainedControllerType in
                    switch section {
                    case .account: return .account
                    case .timePeriods: return .timePeriods
                    }
                }.map { $0.rawValue }
    }
}
