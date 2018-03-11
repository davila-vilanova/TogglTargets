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

class ActivityViewController: NSViewController, ViewControllerContaining {
    internal func connectInterface(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        enforceOnce(for: "ActivityViewController.connectInterface()") { [unowned self] in
            self.activitiesState.input <~ source
        }
    }

    internal lazy var wantsDisplay = Property<Bool>(initial: false, then: activityStatuses.producer.map { !$0.isEmpty })
    internal lazy var wantsExtendedDisplay = Property<Bool>(initial: false,
                                                            then: wantsDisplay.producer.and(requestExtendedDisplayPipe.output.logValues("wantsExtendedDisplay"))
                                                                )

    private let (lifetime, token) = Lifetime.make()
    private let activitiesState = ActivitiesState()
    private lazy var activityStatuses = Property(initial: [ActivityStatus](), then: activitiesState.output)
    private let requestExtendedDisplayPipe = Signal<Bool, NoError>.pipe()

    @IBOutlet weak var condensedActivityView: NSView!
    @IBOutlet weak var collectionView: NSCollectionView!

    var condensedActivityViewController: CondensedActivityViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let condensedActivityViewController = controller as? CondensedActivityViewController {
            self.condensedActivityViewController = condensedActivityViewController
            displayController(condensedActivityViewController, in: condensedActivityView)
        }
    }
    private let areViewsAvailable = MutableProperty(false)

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [CondensedActivityVCContainment])

        (collectionView.collectionViewLayout as! NSCollectionViewGridLayout).maximumNumberOfColumns = 1
        collectionView.register(ActivityCollectionViewItem.self,
                                forItemWithIdentifier: NSUserInterfaceItemIdentifier("ActivityCollectionViewItem"))

        let updateCollectionView = BindingTarget<[ActivityStatus]>(on: UIScheduler(), lifetime: self.lifetime) {
            self.collectionView.content = $0
        }
        updateCollectionView <~ self.activityStatuses.producer
        self.lifetime.observeEnded {
            _ = updateCollectionView
        }

        condensedActivityViewController.connectInterface(
            activityStatuses: activityStatuses.producer,
            expandDetails: BindingTarget(on: UIScheduler(), lifetime: lifetime, action: {
                [observer = requestExtendedDisplayPipe.input] in observer.send(value: $0)
            }))

        areViewsAvailable.value = true

        collectionView.reactive
            .makeBindingTarget(on: UIScheduler()) { $0.isHidden = $1 } <~ requestExtendedDisplayPipe.output.negate()


        _ = wantsExtendedDisplay
    }
}

private extension Array where Element == ActivityStatus {
    var hasExecutingActivities: Bool {
        return self.filter { $0.isExecuting }.count > 0
    }
    var hasErrors: Bool {
        return self.filter { $0.isError }.count > 0
    }
}
