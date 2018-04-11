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

struct AnimationSettings {
    let duration: TimeInterval
    let layoutRootIdentifier: NSUserInterfaceItemIdentifier

    func layoutFromLayoutRootIfNeeded(findLayoutRootFrom view: NSView) {
        view.findSuperview(with: layoutRootIdentifier)?.layoutSubtreeIfNeeded()
    }
    func animate(in view: NSView, changes: () -> Void, completion: @escaping () -> Void = { }) {
        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            context.duration = duration
            changes()
            layoutFromLayoutRootIfNeeded(findLayoutRootFrom: view)
        }, completionHandler: completion)
    }
}

class ActivityViewController: NSViewController, ViewControllerContaining {
    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>,
                                animationSettings: SignalProducer<AnimationSettings?, NoError>) {
        enforceOnce(for: "ActivityViewController.connectInterface()") { [unowned self] in
            self.activitiesState.input <~ source
            self.animationSettings <~ animationSettings
        }
    }
    internal var animationSettings = MutableProperty<AnimationSettings?>(nil)

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

        detailedActivityViewController.connectInterface(activityStatuses: statusesForDetailedActivityVC,
                                                        animationSettings: animationSettings.producer)

        condensedActivityViewController.connectInterface(activityStatuses: activityStatuses.producer,
                                                         animationSettings: animationSettings.producer,
                                                         expandDetails: wantsExtendedDisplay.bindingTarget)

        detailedActivityViewController.view.reactive.makeBindingTarget(on: UIScheduler(), { $0.isHidden = $1 })
            <~ wantsExtendedDisplay.negate()
    }
}

extension NSView {
    func findSuperview(with identifier: NSUserInterfaceItemIdentifier) -> NSView? {
        guard let superview = superview else {
            return nil
        }
        return superview.identifier == identifier ? superview : superview.findSuperview(with: identifier)
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
