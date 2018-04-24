//
//  ActivityViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 28.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

fileprivate let CondensedActivityVCContainment = "CondensedActivityVCContainment"
fileprivate let DetailedActivityVCContainment = "DetailedActivityVCContainment"

class ActivityViewController: NSViewController, ViewControllerContaining, BindingTargetProvider {

    internal typealias Interface =
        (modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>,
        requestDisplay: BindingTarget<Bool>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    private let wantsExtendedDisplay = MutableProperty(false)

    private let (lifetime, token) = Lifetime.make()
    private let activitiesState = ActivitiesState()

    @IBOutlet weak var rootStackView: NSStackView!

    private var condensedActivityViewController: CondensedActivityViewController!
    private var detailedActivityViewController: DetailedActivityViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let condensedActivityVC = controller as? CondensedActivityViewController {
            self.condensedActivityViewController = condensedActivityVC
            rootStackView.addArrangedSubview(condensedActivityVC.view)
        } else if let detailedActivityVC = controller as? DetailedActivityViewController {
            self.detailedActivityViewController = detailedActivityVC
            rootStackView.addArrangedSubview(detailedActivityVC.view)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [CondensedActivityVCContainment, DetailedActivityVCContainment])

        activitiesState.input <~ lastBinding.latestOutput { $0.modelRetrievalStatus }

        condensedActivityViewController <~
            SignalProducer<CondensedActivityViewController.Interface, NoError>(
                value: (activitiesState.output.producer, wantsExtendedDisplay.bindingTarget))

        let statusesForDetailedActivityVC =
            SignalProducer.merge(activitiesState.output.producer.throttle(while: wantsExtendedDisplay.negate(), on: UIScheduler()),
                                 wantsExtendedDisplay.producer.filter { !$0 }.map { _ in [ActivityStatus]() } )

        detailedActivityViewController <~ SignalProducer(value: statusesForDetailedActivityVC)

        let wantsDisplay = Property<Bool>(initial: true, then: activitiesState.output.map { !$0.isEmpty })
        lifetime += wantsDisplay.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.requestDisplay })

        detailedActivityViewController.view.reactive.makeBindingTarget(on: UIScheduler(), { $0.isHidden = $1 })
            <~ wantsExtendedDisplay.negate()
    }
}

fileprivate extension Array where Element == ActivityStatus {
    var hasExecutingActivities: Bool {
        return self.filter { $0.isExecuting }.count > 0
    }
    var hasErrors: Bool {
        return self.filter { $0.isError }.count > 0
    }
}
