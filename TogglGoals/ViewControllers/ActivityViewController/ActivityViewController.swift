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

    private let activitiesState = ActivitiesState()

    @IBOutlet weak var rootStackView: NSStackView!

    private lazy var condensedActivityViewController: CondensedActivityViewController = {
        let condensed = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("CondensedActivityViewController")) as! CondensedActivityViewController
        condensed <~
            SignalProducer<CondensedActivityViewController.Interface, NoError>(
                value: (activitiesState.output.producer, wantsExtendedDisplay.bindingTarget))
        return condensed
    }()

    private lazy var detailedActivityViewController: DetailedActivityViewController = {
        let detailed = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("DetailedActivityViewController")) as! DetailedActivityViewController

        let heldStatuses = Property(initial: [ActivityStatus](), then: activitiesState.output.producer)
        let statuses =
            SignalProducer.merge(heldStatuses.producer.throttle(while: wantsExtendedDisplay.negate(), on: UIScheduler()),
                                 heldStatuses.producer.sample(on: wantsExtendedDisplay.producer.filter { $0 }.map { _ in () }),
                                 wantsExtendedDisplay.producer.filter { !$0 }.map { _ in [ActivityStatus]() } )
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
        addChildViewController(condensedActivityViewController)
        rootStackView.addArrangedSubview(detailedActivityViewController.view)
        addChildViewController(detailedActivityViewController)

        activitiesState.input <~ lastBinding.latestOutput { $0.modelRetrievalStatus }
    }
}
