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

fileprivate let ActivityRemovalDelay = TimeInterval(2.0)

class ActivityViewController: NSViewController, NSCollectionViewDataSource {

    private let backgroundScheduler = QueueScheduler()

    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        func setUpInternalConnections() {
            func areStatusesCollapsable(_ statuses: [ActivityStatus]) -> Bool {
                if statuses.count < ActivityStatus.Activity.individualActivityCount {
                    return false
                }
                return (statuses.filter { $0.isSuccessful }.count) == statuses.count
            }

            let unfilteredCollectStatusesOutput = collectActivityStatuses.values
            let filteredCollectStatusesOutput = unfilteredCollectStatusesOutput.filter { !areStatusesCollapsable($0.0) }

            collectedStatuses <~ Signal.merge(unfilteredCollectStatusesOutput.map { $0.0 },
                                              cleanUpCollectedSuccessfulStatuses.values)

            collapseAllStatusesIntoSuccess.serialInput <~ collectedStatuses.producer.filter(areStatusesCollapsable).map { _ in () }


            cleanUpCollectedSuccessfulStatuses <~ cleanUpDisplayedSuccessfulStatuses.values.map { _ in ()}

            displayStatuses <~ Signal.merge(filteredCollectStatusesOutput.map { $0.0 },
                                            collapseAllStatusesIntoSuccess.values.map { $0.0 },
                                            cleanUpDisplayedSuccessfulStatuses.values.map { $0.0 })
                .observe(on: UIScheduler())

            updateCollectionView.serialInput <~ Signal.merge(filteredCollectStatusesOutput.map { $0.1 },
                                                             collapseAllStatusesIntoSuccess.values.map { $0.1 }.skipNil()
                                                                .map { SignalProducer($0) }.flatten(.concat),
                                                             cleanUpDisplayedSuccessfulStatuses.values.map { $0.1 })
                .observe(on: UIScheduler())

        }

        enforceOnce(for: "ActivityViewController.connectInputs()") {
            setUpInternalConnections()

            self.collectActivityStatuses.serialInput <~ source.observe(on: self.backgroundScheduler)
            self.cleanUpDisplayedSuccessfulStatuses.serialInput <~ source.filter { $0.isSuccessful }
                .debounce(ActivityRemovalDelay, on: self.backgroundScheduler)
                .map { _ in () }

        }
    }

    internal lazy var wantsDisplay = Property<Bool>(initial: false, then: displayStatuses.producer.map { !$0.isEmpty })

    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()
    private let collectedStatuses = MutableProperty([ActivityStatus]())
    private let displayStatuses = MutableProperty([ActivityStatus]())

    private enum CollectionViewUpdate {
        case update(at: Int)
        case addition(at: Int)
        case removal(of: Set<Int>)
    }

    private lazy var collectActivityStatuses = Action<ActivityStatus, ([ActivityStatus], CollectionViewUpdate), NoError>(state: collectedStatuses) { (currentActivityStatuses, newStatus) in

        var updatedStatuses = currentActivityStatuses
        let change: CollectionViewUpdate

        if let index = updatedStatuses.index(where: { $0.activity == newStatus.activity }) {
            updatedStatuses[index] = newStatus
            change = .update(at: index)
        } else {
            let index = updatedStatuses.endIndex
            updatedStatuses.insert(newStatus, at: index)
            change = .addition(at: index)
        }

        return SignalProducer(value: (updatedStatuses, change))
    }

    private lazy var collapseAllStatusesIntoSuccess = Action<Void, ([ActivityStatus], [CollectionViewUpdate]?), NoError>(state: displayStatuses){ statuses in

        var collectionViewUpdates = [CollectionViewUpdate]()

        if statuses.endIndex > 1 {
            var indexesToDelete = Set<Int>()
            for index in 1 ..< statuses.endIndex {
                indexesToDelete.insert(index)
            }
            collectionViewUpdates.append(.removal(of: indexesToDelete))
        }

        collectionViewUpdates.append(.update(at: 0))

        return SignalProducer(value: ([ActivityStatus.allSuccessful], collectionViewUpdates))
    }

    private lazy var cleanUpCollectedSuccessfulStatuses = Action<Void, [ActivityStatus], NoError>(state: collectedStatuses) { statuses in
        return SignalProducer(value: statuses.filter { !$0.isSuccessful })
    }

    private lazy var cleanUpDisplayedSuccessfulStatuses = Action<Void, ([ActivityStatus], CollectionViewUpdate), NoError>(state: displayStatuses) { statuses in
        var cleanedUpStatuses = [ActivityStatus]()
        var indexes = Set<Int>()
        for index in statuses.startIndex ..< statuses.endIndex {
            let status = statuses[index]
            if status.isSuccessful {
                indexes.insert(index)
            } else {
                cleanedUpStatuses.append(status)
            }
        }

        return SignalProducer(value: (cleanedUpStatuses, .removal(of: indexes)))
    }

    private lazy var updateCollectionView = Action<CollectionViewUpdate, Void, NoError>(unwrapping: collectionViewProperty) { (collectionView, collectionViewUpdate) in
        switch collectionViewUpdate {
        case .update(let index): collectionView.reloadItems(at: index.asIndexPaths)
        case .addition(let index): collectionView.animator().insertItems(at: index.asIndexPaths)
        case .removal(let indexes): collectionView.animator().deleteItems(at: indexes.asIndexPaths)
        }

        return SignalProducer.empty
    }

    @IBOutlet weak var collectionView: NSCollectionView!

    let collectionViewProperty = MutableProperty<NSCollectionView?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        for (name, identifier) in RawNibNamesToIdentifiers {
            let nib = NSNib(nibNamed: NSNib.Name(rawValue: name), bundle: nil)!
            collectionView.register(nib, forItemWithIdentifier: identifier)
        }

        collectionViewProperty.value = collectionView

        (collectionView.collectionViewLayout as! NSCollectionViewGridLayout).maximumNumberOfColumns = 1
        collectionView.reloadData()
    }


    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayStatuses.value.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let activityStatus = displayStatuses.value[indexPath.item]

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

fileprivate extension ActivityStatus {
    static var allSuccessful: ActivityStatus {
        return ActivityStatus.succeeded(.all)
    }
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

