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

    private var inputsConnected = false

    private let backgroundScheduler = QueueScheduler()

    internal func connectInputs(modelRetrievalStatus: SignalProducer<ActivityStatus, NoError>) {
        UIScheduler().schedule { [unowned self] in
            guard !self.inputsConnected else {
                fatalError("Inputs must not be connected more than once.")
            }
            self.activityStatuses <~ Signal.merge(self.updateActivityStatuses.values.map { $0.0 },
                                                  self.cleanUpSuccessfulStatuses.values.map { $0.0 })

            self.updateActivityStatuses.serialInput <~ modelRetrievalStatus.observe(on: self.backgroundScheduler)
            self.cleanUpSuccessfulStatuses.serialInput <~ modelRetrievalStatus.filter { $0.isSuccessful }.debounce(ActivityRemovalDelay, on: self.backgroundScheduler).map { _ in () }

            self.inputsConnected = true
        }
    }


    internal lazy var wantsDisplay = Property<Bool>(initial: false, then: activityStatuses.producer.map { !$0.isEmpty })

    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()
    private let activityStatuses = MutableProperty([ActivityStatus]())

    enum ActivityStatusChange {
        case update(at: Int)
        case addition(at: Int)
    }

    private lazy var updateActivityStatuses = Action<ActivityStatus, ([ActivityStatus], ActivityStatusChange), NoError>(state: activityStatuses) { (currentActivityStatuses, newStatus) in

        var updatedStatuses = currentActivityStatuses
        let changeInStatuses: ActivityStatusChange

        if let index = updatedStatuses.index(where: { $0.activity == newStatus.activity }) {
            updatedStatuses[index] = newStatus
            changeInStatuses = .update(at: index)
        } else {
            let index = updatedStatuses.endIndex
            updatedStatuses.insert(newStatus, at: index)
            changeInStatuses = .addition(at: index)
        }

        return SignalProducer(value: (updatedStatuses, changeInStatuses))
    }

    private lazy var cleanUpSuccessfulStatuses = Action<Void, ([ActivityStatus], [Int]), NoError>(state: activityStatuses) { currentStatuses in
        var cleanedUpStatuses = [ActivityStatus]()
        var indexesToRemove = [Int]()
        for index in currentStatuses.startIndex ..< currentStatuses.endIndex {
            let status = currentStatuses[index]
            if status.isSuccessful {
                indexesToRemove.append(index)
            } else {
                cleanedUpStatuses.append(status)
            }
        }

        return SignalProducer(value: (cleanedUpStatuses, indexesToRemove))
    }

    private lazy var updateCollectionView = Action<ActivityStatusChange, Void, NoError> { [weak self] activityChange in
        guard let vc = self,
            let collectionView = vc.collectionView else {
                return SignalProducer.empty
        }

        switch activityChange {
        case .update(let index): collectionView.reloadItems(at: index.asIndexPaths)
        case .addition(let index): collectionView.animator().insertItems(at: index.asIndexPaths)
        }

        return SignalProducer.empty
    }

    private lazy var removeItemsFromCollectionView = Action<[Int], Void, NoError> { [weak self] indexesToRemove in
        guard let vc = self,
            let collectionView = vc.collectionView else {
                return SignalProducer.empty
        }

        let indexPaths = indexesToRemove.map { $0.asIndexPath }
        collectionView.animator().deleteItems(at: Set(indexPaths))
        return SignalProducer.empty
    }

    @IBOutlet weak var collectionView: NSCollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        for (name, identifier) in RawNibNamesToIdentifiers {
            let nib = NSNib(nibNamed: NSNib.Name(rawValue: name), bundle: nil)!
            collectionView.register(nib, forItemWithIdentifier: identifier)
        }

        updateCollectionView.serialInput <~ updateActivityStatuses.values.map { $0.1 }.observe(on: UIScheduler())
        removeItemsFromCollectionView.serialInput <~ cleanUpSuccessfulStatuses.values.map { $0.1 }.observe(on: UIScheduler())

        (collectionView.collectionViewLayout as! NSCollectionViewGridLayout).maximumNumberOfColumns = 1
        collectionView.reloadData()
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

fileprivate extension ActivityStatus {
    var isSuccessful: Bool {
        switch self {
        case .succeeded: return true
        default: return false
        }
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

    }
}
