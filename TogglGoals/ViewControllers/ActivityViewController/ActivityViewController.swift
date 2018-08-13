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

class ActivityViewController: NSViewController, BindingTargetProvider {

    internal typealias Interface =
        (modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>,
        requestDisplay: BindingTarget<Bool>)

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    private let wantsExtendedDisplay = MutableProperty(false)

    private let (lifetime, token) = Lifetime.make()
    private let activitiesState = ActivitiesState()

    @IBOutlet weak var rootStackView: NSStackView!

    private lazy var condensedActivityViewController: CondensedActivityViewController = {
        let condensed = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("CondensedActivityViewController")) as! CondensedActivityViewController
        addChildViewController(condensed)
        rootStackView.addArrangedSubview(condensed.view)
        condensed <~
            SignalProducer<CondensedActivityViewController.Interface, NoError>(
                value: (activitiesState.output.producer, wantsExtendedDisplay.bindingTarget))
        return condensed
    }()

    private lazy var detailedActivityViewController: DetailedActivityViewController = {
        let detailed = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("DetailedActivityViewController")) as! DetailedActivityViewController
        addChildViewController(detailed)
        rootStackView.addArrangedSubview(detailed.view)

        let statuses =
            SignalProducer.merge(activitiesState.output.producer.throttle(while: wantsExtendedDisplay.negate(), on: UIScheduler()),
                                 wantsExtendedDisplay.producer.filter { !$0 }.map { _ in [ActivityStatus]() } )
        let wantsDisplay = Property<Bool>(initial: true, then: activitiesState.output.map { !$0.isEmpty })
        lifetime += wantsDisplay.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.requestDisplay })

        detailed <~ SignalProducer(value: statuses)
        detailed.view.reactive.makeBindingTarget(on: UIScheduler(), { $0.isHidden = $1 })
            <~ wantsExtendedDisplay.negate()

        return detailed
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        _ = condensedActivityViewController
        _ = detailedActivityViewController
        activitiesState.input <~ lastBinding.latestOutput { $0.modelRetrievalStatus }
    }
}
