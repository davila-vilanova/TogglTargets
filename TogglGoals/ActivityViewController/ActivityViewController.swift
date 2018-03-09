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
    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        enforceOnce(for: "ActivityViewController.connectInputs()") { [unowned self] in
            self.setUpInternalConnections()
            self.activitiesState.input <~ source
            self.areViewsAvailable.firstTrue.startWithValues {
                self.condensedActivityViewController.connectInputs(activityStatuses: self.activityStatuses.producer)
            }
        }
    }

    internal lazy var wantsDisplay = Property<Bool>(initial: false, then: activityStatuses.producer.map { !$0.isEmpty })

    private let (lifetime, token) = Lifetime.make()
    private let activitiesState = ActivitiesState()
    private let activityStatuses = MutableProperty([ActivityStatus]())

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
        areViewsAvailable.value = true

        collectionView.register(ActivityCollectionViewItem.self,
                                forItemWithIdentifier: NSUserInterfaceItemIdentifier("ActivityCollectionViewItem"))
    }

    private func setUpInternalConnections() {
        activityStatuses <~ activitiesState.output

        areViewsAvailable.firstTrue.startWithValues { [unowned self]  in
            let updateCollectionView = BindingTarget<[ActivityStatus]>(on: UIScheduler(), lifetime: self.lifetime) {
                self.collectionView.content = $0
            }
            updateCollectionView <~ self.activityStatuses.producer
            self.lifetime.observeEnded {
                _ = updateCollectionView
            }
        }
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
