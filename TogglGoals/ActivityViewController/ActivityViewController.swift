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

class ActivityViewController: NSViewController {
    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        func setUpInternalConnections() {
            activityStatuses <~ activitiesState.output
            isCollectionViewAvailable.firstTrue.startWithValues { [unowned self]  in
                let target = BindingTarget<[ActivityStatus]>(on: UIScheduler(), lifetime: self.lifetime) {
                    self.collectionView.content = $0
                }
                target <~ self.activityStatuses.producer
                self.lifetime.observeEnded {
                    _ = target
                }
            }
        }

        enforceOnce(for: "ActivityViewController.connectInputs()") { [unowned self] in
            setUpInternalConnections()
            self.activitiesState.input <~ source
        }
    }

    internal lazy var wantsDisplay = Property<Bool>(initial: false, then: activityStatuses.producer.map { !$0.isEmpty })

    private let (lifetime, token) = Lifetime.make()
    private let activityStatuses = MutableProperty([ActivityStatus]())
    private let activitiesState = ActivitiesState()

    @IBOutlet weak var collectionView: NSCollectionView!

    private let isCollectionViewAvailable = MutableProperty(false)

    override func viewDidLoad() {
        super.viewDidLoad()

        (collectionView.collectionViewLayout as! NSCollectionViewGridLayout).maximumNumberOfColumns = 1
        isCollectionViewAvailable.value = true

        collectionView.register(ActivityCollectionViewItem.self,
                                forItemWithIdentifier: NSUserInterfaceItemIdentifier("ActivityCollectionViewItem"))
    }
}

protocol ActivityDisplaying {
    func setDisplayActivity(_ activity: ActivityStatus.Activity)
}
