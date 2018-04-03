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

fileprivate let kActivityListAnimationDuration = 0.10

fileprivate let CondensedActivityVCContainment = "CondensedActivityVCContainment"
fileprivate let DetailedActivityVCContainment = "DetailedActivityVCContainment"

class ActivityViewController: NSViewController, ViewControllerContaining {
    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        enforceOnce(for: "ActivityViewController.connectInterface()") { [unowned self] in
            self.activitiesState.input <~ source
        }
    }

    internal lazy var wantsDisplay = Property(value: true) //Property<Bool>(initial: false, then: activityStatuses.producer.map { !$0.isEmpty })

    private let (lifetime, token) = Lifetime.make()
    private let activitiesState = ActivitiesState()
    private lazy var activityStatuses = Property(initial: [ActivityStatus](), then: activitiesState.output)

    @IBOutlet weak var condensedActivityView: NSView!
    @IBOutlet weak var detailedActivityView: NSView!

    @IBOutlet weak var rootHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var condensedActivityViewHeightConstraint: NSLayoutConstraint!

    private var condensedActivityViewController: CondensedActivityViewController!
    private var detailedActivityViewController: DetailedActivityViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let condensedActivityVC = controller as? CondensedActivityViewController {
            self.condensedActivityViewController = condensedActivityVC
            displayController(condensedActivityVC, in: condensedActivityView)
        } else if let detailedActivityVC = controller as? DetailedActivityViewController {
            self.detailedActivityViewController = detailedActivityVC
            displayController(detailedActivityVC, in: detailedActivityView)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [CondensedActivityVCContainment, DetailedActivityVCContainment])

        let detailedViewFittingHeight = MutableProperty<CGFloat>(0)
        let wantsExtendedDisplay = MutableProperty(false)
        lifetime.observeEnded {
            _ = detailedViewFittingHeight
            _ = wantsExtendedDisplay
        }

        detailedActivityViewController.connectInterface(activityStatuses: self.activityStatuses.producer, fittingHeight: detailedViewFittingHeight.bindingTarget, animationDuration: kActivityListAnimationDuration)

        condensedActivityViewController.connectInterface(activityStatuses: activityStatuses.producer, expandDetails: wantsExtendedDisplay.bindingTarget)

        detailedActivityView.reactive.makeBindingTarget(on: UIScheduler(), animateOpacity)
            <~ wantsExtendedDisplay.map { $0 ? (0.0, 1.0) : (1.0, 0.0) }

        let collapsedHeight = condensedActivityViewHeightConstraint.constant

        let detailedViewHeight = SignalProducer.combineLatest(wantsExtendedDisplay, detailedViewFittingHeight).map { $0 ? $1 : 0 }

        let heightTarget =  rootHeightConstraint.reactive.makeBindingTarget(on: UIScheduler()) { (constraint: NSLayoutConstraint, height: CGFloat) in
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.10
            constraint.animator().constant = height
            NSAnimationContext.endGrouping()
        }

        heightTarget <~ detailedViewHeight.map { collapsedHeight + $0 }
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

fileprivate func animateOpacity(view: NSView, values: (from: Double, to: Double)) {
    guard let layer = view.layer else {
        return
    }
    let (from, to) = values
    let opacityKey = "opacity"
    let animation = CABasicAnimation(keyPath: opacityKey)
    animation.fromValue = from
    animation.toValue = to
    layer.add(animation, forKey: opacityKey)
}
