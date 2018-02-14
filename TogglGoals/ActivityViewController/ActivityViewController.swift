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

fileprivate let RetrievalInProgressItem = "ActivityCollectionViewProgressItem"
fileprivate let RetrievalSuccessItem = "ActivityCollectionViewSuccessItem"
fileprivate let RetrievalErrorItem = "ActivityCollectionViewErrorItem"

fileprivate let RetrievalInProgressItemIdentifier = NSUserInterfaceItemIdentifier(RetrievalInProgressItem)
fileprivate let RetrievalSuccessItemIdentifier = NSUserInterfaceItemIdentifier(RetrievalSuccessItem)
fileprivate let RetrievalErrorItemIdentifier = NSUserInterfaceItemIdentifier(RetrievalErrorItem)

fileprivate let RawNibNamesToIdentifiers = [ RetrievalInProgressItem : RetrievalInProgressItemIdentifier,
                                             RetrievalSuccessItem : RetrievalSuccessItemIdentifier,
                                             RetrievalErrorItem : RetrievalErrorItemIdentifier ]

fileprivate let CollectionViewThrottleDelay = TimeInterval(0.5)

class ActivityViewController: NSViewController, NSCollectionViewDataSource {
    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        func setUpInternalConnections() {
            activityStatuses <~ activitiesState.output.throttle(CollectionViewThrottleDelay, on: QueueScheduler())
            isCollectionViewAvailable.firstTrue.startWithValues { [unowned self] _ in
                self.collectionView.reactive.reloadData <~ self.activityStatuses.producer.map { _ in () }
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

        for (name, identifier) in RawNibNamesToIdentifiers {
            let nib = NSNib(nibNamed: NSNib.Name(rawValue: name), bundle: nil)!
            collectionView.register(nib, forItemWithIdentifier: identifier)
        }

        (collectionView.collectionViewLayout as! NSCollectionViewGridLayout).maximumNumberOfColumns = 1
        isCollectionViewAvailable.value = true
    }


    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return activityStatuses.value.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let activityStatus = activityStatuses.value[indexPath.item]

        let item: NSCollectionViewItem
        switch activityStatus {
        case .executing:
            item = collectionView.makeItem(withIdentifier: RetrievalInProgressItemIdentifier, for: indexPath)
        case .succeeded:
            item = collectionView.makeItem(withIdentifier: RetrievalSuccessItemIdentifier, for: indexPath)
        case .error(_, let error, let retryAction):
           item = collectionView.makeItem(withIdentifier: RetrievalErrorItemIdentifier, for: indexPath)

           if let errorItem = item as? ActivityCollectionViewErrorItem {
            errorItem.setError(error)
            errorItem.setRetryAction(retryAction)
           } else {
            assert(false, "ActivityViewController error: expected an ActivityCollectionViewErrorItem registered to display items with .error status. Got (\(String(describing: item)) instead.")
            }
        }

        if let activityDisplayingItem = item as? ActivityDisplaying {
            activityDisplayingItem.setDisplayActivity(activityStatus.activity)
        } else {
            assert(false, "ActivityViewController error: expected an ActivityDisplayingItem registered to display items with \(activityStatus) status. Got (\(String(describing: item)) instead.")
        }

        return item
    }
}

protocol ActivityDisplaying {
    func setDisplayActivity(_ activity: ActivityStatus.Activity)
}

fileprivate extension Array.Index {
    /// CollectionView with a single section, such as the activity collection view
    var asIndexPaths: Set<IndexPath> {
        return Set([asIndexPath])
    }

    var asIndexPath: IndexPath {
        return IndexPath(item: self, section: 0)
    }
}

fileprivate extension Set where Element == Int {
    var asIndexPaths: Set<IndexPath> {
        return Set<IndexPath>(self.map { $0.asIndexPath })
    }
}

