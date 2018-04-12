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

class ActivityViewController: NSViewController, ViewControllerContaining {
    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        enforceOnce(for: "ActivityViewController.connectInterface()") { [unowned self] in
            self.activitiesState.input <~ source
        }
    }

    internal lazy var wantsDisplay = Property<Bool>(initial: true, then: activityStatuses.producer.map { !$0.isEmpty })

    private let (lifetime, token) = Lifetime.make()
    private let activitiesState = ActivitiesState()
    private lazy var activityStatuses = Property(initial: [ActivityStatus](), then: activitiesState.output)

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

        let wantsExtendedDisplay = MutableProperty(false)
        lifetime.observeEnded {
            _ = wantsExtendedDisplay
        }

        let statusesForDetailedActivityVC =
            SignalProducer.merge(activityStatuses.producer.throttle(while: wantsExtendedDisplay.negate(), on: UIScheduler()),
                                 wantsExtendedDisplay.producer.filter { !$0 }.map { _ in [ActivityStatus]() } )

        detailedActivityViewController.connectInterface(activityStatuses: statusesForDetailedActivityVC)

        condensedActivityViewController.connectInterface(activityStatuses: activityStatuses.producer,
                                                         expandDetails: wantsExtendedDisplay.bindingTarget)

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
