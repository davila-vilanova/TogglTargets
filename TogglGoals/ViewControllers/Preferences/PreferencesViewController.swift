//
//  PreferencesViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

class PreferencesViewController: NSTabViewController, BindingTargetProvider {
    internal enum Section {
        case account
        case goalPeriods
    }
    // MARK: - Interface

    internal typealias Interface = (
        displaySection: SignalProducer<Section?, NoError>,
        existingCredential: SignalProducer<TogglAPITokenCredential?, NoError>,
        resolvedCredential: BindingTarget<TogglAPITokenCredential?>,
        testURLSessionAction: RetrieveProfileNetworkAction,
        existingGoalPeriodPreference: SignalProducer<PeriodPreference, NoError>,
        calendar: SignalProducer<Calendar, NoError>,
        currentDate: SignalProducer<Date, NoError>,
        updatedGoalPeriodPreference: BindingTarget<PeriodPreference>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    // MARK: - Contained view controllers

    private enum ContainedControllerType: Int {
        case account = 0
        case goalPeriods = 1

        static func from(_ controller: NSViewController) -> ContainedControllerType? {
            if controller as? AccountViewController != nil {
                return .account
            } else if controller as? GoalPeriodsPreferencesViewController != nil {
                return .goalPeriods
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
            account <~ validBindings.map { ($0.existingCredential, $0.resolvedCredential, $0.testURLSessionAction) }
        } else if let goalPeriods = controller as? GoalPeriodsPreferencesViewController {
            goalPeriods <~ validBindings.map { ($0.calendar, $0.currentDate, $0.existingGoalPeriodPreference, $0.updatedGoalPeriodPreference) }
        }
    }

    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        self.reactive.makeBindingTarget(on: UIScheduler()) { $0.selectedTabViewItemIndex = $1 } <~ lastBinding.latestOutput { $0.displaySection }
            .skipNil().map { section -> ContainedControllerType in
                switch section {
                case .account: return .account
                case .goalPeriods: return .goalPeriods
                }
            }.map { $0.rawValue }
    }
}
