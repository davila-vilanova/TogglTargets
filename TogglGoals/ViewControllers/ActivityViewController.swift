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

fileprivate let ActivityRemovalDelay = TimeInterval(3.0)

class ActivityViewController: NSViewController, NSCollectionViewDataSource {

    internal func connectInputs(modelRetrievalStatus: SignalProducer<(RetrievalActivity, ActivityStatus), NoError>) {
        updateState <~ modelRetrievalStatus
        removeActivityDelayer <~ modelRetrievalStatus.filter { $0.1.isSuccess }.map { _ in () }
    }


    internal lazy var wantsDisplay = Property<Bool>(initial: false, then: requestDisplay.output.producer)

    private let requestDisplay = Signal<Bool, NoError>.pipe()

    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()
    private var activities = [RetrievalActivity]() {
        didSet {
            requestDisplay.input.send(value: activities.count > 0)
        }
    }
    private var statuses = [RetrievalActivity : ActivityStatus]()
    private let removeActivityDelayer = ResetableDelayer(with: ActivityRemovalDelay)

    private lazy var updateState = BindingTarget<(RetrievalActivity, ActivityStatus)>(on: UIScheduler(), lifetime: lifetime) { [weak self] update in
        guard let vc = self else {
            return
        }
        let (activity, status) = update
        vc.statuses[activity] = status

        enum Change {
            case update(at: Int)
            case addition(at: Int)
        }

        let changeInActivities: Change

        if let index = vc.activities.index(of: activity) {
            changeInActivities = .update(at: index)
        } else {
            let index = vc.activities.endIndex
            vc.activities.insert(activity, at: index)
            changeInActivities = .addition(at: index)
        }

        if let collectionView = vc.collectionView {
            switch changeInActivities {
            case .update(let index): vc.collectionView.reloadItems(at: index.asIndexPaths)
            case .addition(let index): vc.collectionView.animator().insertItems(at: index.asIndexPaths)
            }
        }
    }

    private lazy var removeSucceededActivities = BindingTarget<Void>(on: UIScheduler(), lifetime: lifetime) { [weak self] in
        guard let vc = self else {
            return
        }

        var toRemove = [Int]()
        for index in vc.activities.startIndex ..< vc.activities.endIndex {
            let activity = vc.activities[index]
            if let status = vc.statuses[activity], status.isSuccess {
                toRemove.append(index)
            }
        }

        for index in toRemove.reversed() {
            let activity = vc.activities.remove(at: index)
            vc.statuses.removeValue(forKey: activity)
        }

        if let collectionView = vc.collectionView {
            collectionView.animator().deleteItems(at: Set(toRemove.map { $0.asIndexPath }))
        }
     }

    @IBOutlet weak var collectionView: NSCollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        for (name, identifier) in RawNibNamesToIdentifiers {
            let nib = NSNib(nibNamed: NSNib.Name(rawValue: name), bundle: nil)!
            collectionView.register(nib, forItemWithIdentifier: identifier)
        }

        removeSucceededActivities <~ removeActivityDelayer

        (collectionView.collectionViewLayout as! NSCollectionViewGridLayout).maximumNumberOfColumns = 1
        collectionView.reloadData()
    }


    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return activities.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let activity = activities[indexPath.item]
        guard let status = statuses[activity] else {
            // Should never happen because the status for a given activity is
            // always added to the `statuses` Dictionary upon reception.
            fatalError("ActivityViewController error: status for activity \(String(describing: activity)) is not available at display time.")
        }

        let item: NSCollectionViewItem
        switch status {
        case .executing:
            item = collectionView.makeItem(withIdentifier: RetrievalInProgressItemIdentifier, for: indexPath)
        case .succeeded:
            item = collectionView.makeItem(withIdentifier: RetrievalSuccessItemIdentifier, for: indexPath)
        case .error(let error, let retryAction):
           item = collectionView.makeItem(withIdentifier: RetrievalErrorItemIdentifier, for: indexPath)

           if let errorItem = item as? ActivityCollectionViewErrorItem {
            errorItem.setError(error)
            errorItem.setRetryAction(retryAction)
           } else {
            assert(false, "ActivityViewController error: expected an ActivityCollectionViewErrorItem registered to display items with .error status. Got (\(String(describing: item)) instead.")
            }
        }

        if let activityDisplayingItem = item as? ActivityDisplaying {
            activityDisplayingItem.setDisplayActivity(activity)
        } else {
            assert(false, "ActivityViewController error: expected an ActivityDisplayingItem registered to display items with \(status) status. Got (\(String(describing: item)) instead.")
        }

        return item
    }
}

protocol ActivityDisplaying {
    func setDisplayActivity(_ activity: RetrievalActivity)
}

fileprivate extension ActivityStatus {
    var isSuccess: Bool {
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

fileprivate class ResetableDelayer: BindingTargetProvider, BindingSource {
    typealias Value = Void
    typealias Error = NoError

    let delay: TimeInterval
    let lifetime: Lifetime
    private let lifetimeToken: Lifetime.Token
    var valueBindingTarget: BindingTarget<Value>!
    let producer: SignalProducer<Value, NoError>
    var bindingTarget: BindingTarget<Value> { return valueBindingTarget }
    private var delayDisposable: Disposable?

    init(with delay: TimeInterval) {
        self.delay = delay
        let (lifetime, token) = Lifetime.make()
        self.lifetime = lifetime
        lifetimeToken = token
        let scheduler = QueueScheduler()
        let pipe = Signal<Value, NoError>.pipe()
        producer = SignalProducer(pipe.output)
        valueBindingTarget = BindingTarget(on: scheduler, lifetime: lifetime) { [unowned self] in
            if let previousDisposable = self.delayDisposable {
                previousDisposable.dispose()
            }
            self.delayDisposable = scheduler.schedule(after: Date().addingTimeInterval(delay)) {
                pipe.input.send(value: ())
                self.delayDisposable = nil
            }
        }
    }
}
