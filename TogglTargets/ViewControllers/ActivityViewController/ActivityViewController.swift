//
//  ActivityViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 28.12.17.
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

class ActivityViewController: NSViewController, BindingTargetProvider {

    internal typealias Interface =
        (modelRetrievalStatus: SignalProducer<ActivityStatus, Never>,
        requestDisplay: BindingTarget<Bool>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    private let wantsExtendedDisplay = MutableProperty(false)

    private let activitiesState = ActivitiesState()

    @IBOutlet weak var rootStackView: NSStackView!

    private lazy var condensedActivityViewController: CondensedActivityViewController = {
        let condensed = self.storyboard!.instantiateController(withIdentifier: "CondensedActivityViewController")
            as! CondensedActivityViewController // swiftlint:disable:this force_cast
        condensed <~
            SignalProducer<CondensedActivityViewController.Interface, Never>(
                value: (activitiesState.output.producer, wantsExtendedDisplay.bindingTarget))
        return condensed
    }()

    private lazy var detailedActivityViewController: DetailedActivityViewController = {
        let detailed = self.storyboard!.instantiateController(withIdentifier: "DetailedActivityViewController")
            as! DetailedActivityViewController // swiftlint:disable:this force_cast

        let heldStatuses = Property(initial: [ActivityStatus](), then: activitiesState.output.producer)
        let statuses =
            SignalProducer.merge(heldStatuses.producer.throttle(while: wantsExtendedDisplay.negate(),
                                                                on: UIScheduler()),
                                 heldStatuses.producer.sample(on: wantsExtendedDisplay.producer.filter { $0 }
                                    .map { _ in () }),
                                 wantsExtendedDisplay.producer.filter { !$0 }.map { _ in [ActivityStatus]() })
        let wantsDisplay = Property<Bool>(initial: true, then: activitiesState.output.map { !$0.isEmpty })
        reactive.lifetime += wantsDisplay.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.requestDisplay })

        detailed <~ SignalProducer(value: statuses)
        detailed.view.reactive.makeBindingTarget(on: UIScheduler(), { $0.isHidden = $1 })
            <~ wantsExtendedDisplay.negate()

        return detailed
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        rootStackView.addArrangedSubview(condensedActivityViewController.view)
        addChild(condensedActivityViewController)
        rootStackView.addArrangedSubview(detailedActivityViewController.view)
        addChild(detailedActivityViewController)

        activitiesState.input <~ lastBinding.latestOutput { $0.modelRetrievalStatus }
    }
}
