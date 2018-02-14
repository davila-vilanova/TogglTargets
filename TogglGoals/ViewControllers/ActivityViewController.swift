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

fileprivate enum CollectionViewUpdate {
    case update(at: Int)
    case addition(at: Int)
    case removal(of: Set<Int>)
    case fullRefresh
}

class ActivityViewController: NSViewController, NSCollectionViewDataSource {
    func setUpInternalConnections() {
        activityStatuses <~ statusesProcessor.output.map { $0.0 }
        updateCollectionView <~ statusesProcessor.output.map { $0.1 }
    }

    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        setUpInternalConnections()
        enforceOnce(for: "ActivityViewController.connectInputs()") { [unowned self] in
            self.statusesProcessor.input <~ source
        }
    }

    internal lazy var wantsDisplay = Property<Bool>(initial: false, then: activityStatuses.producer.map { !$0.isEmpty })

    private let (lifetime, token) = Lifetime.make()
    private let activityStatuses = MutableProperty([ActivityStatus]())
    private let statusesProcessor = ActivityStatusesState()

    private lazy var updateCollectionView = BindingTarget<[CollectionViewUpdate]>(on: UIScheduler(), lifetime: lifetime) { [weak self] updates in
        guard let collectionView = self?.collectionView else {
            return
        }
        for update in updates {
            switch update {
            case .update(let index): collectionView.reloadItems(at: index.asIndexPaths)
            case .addition(let index): collectionView.animator().insertItems(at: index.asIndexPaths)
            case .removal(let indexes): collectionView.animator().deleteItems(at: indexes.asIndexPaths)
            case .fullRefresh: collectionView.animator().reloadData()
            }
        }
    }

    @IBOutlet weak var collectionView: NSCollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        for (name, identifier) in RawNibNamesToIdentifiers {
            let nib = NSNib(nibNamed: NSNib.Name(rawValue: name), bundle: nil)!
            collectionView.register(nib, forItemWithIdentifier: identifier)
        }

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

fileprivate typealias StateProcessor = ([ActivityStatus]) -> ([CollectionViewUpdate], [ActivityStatus])?

fileprivate func collapseIntoSuccess(state: [ActivityStatus]) -> ([CollectionViewUpdate], [ActivityStatus])? {
    func canCollapse() -> Bool {
        if state.count < ActivityStatus.Activity.individualActivityCount {
            return false
        }
        return (state.filter { $0.isSuccessful }.count) == state.count
    }

    guard canCollapse() else {
        return nil
    }

    var updates = [CollectionViewUpdate]()

    if state.endIndex > 1 {
        var indexesToDelete = Set<Int>()
        for index in 1 ..< state.endIndex {
            indexesToDelete.insert(index)
        }
        updates.append(.removal(of: indexesToDelete))
    }

    // Make sure to refresh single remaining item at the end
    updates.append(.update(at: 0))

    return (updates, [ActivityStatus.allSuccessful])
}

fileprivate func collect(_ status: ActivityStatus, _ state: [ActivityStatus]) -> ([CollectionViewUpdate], [ActivityStatus])? {
    var updatedState = state
    if let index = state.index(where: { $0.activity == status.activity }) {
        updatedState[index] = status
        return ([.update(at: index)], updatedState)
    } else {
        let index = updatedState.endIndex
        updatedState.insert(status, at: index)
        return ([.addition(at: index)], updatedState)
    }
}

fileprivate func cleanUpSuccessful(state: [ActivityStatus]) -> ([CollectionViewUpdate], [ActivityStatus])? {
    func anythingToCleanUp() -> Bool {
        return state.contains(where: { $0.isSuccessful })
    }

    guard anythingToCleanUp() else {
        return nil
    }

    var cleanedUp = [ActivityStatus]()
    var indexes = Set<Int>()
    for index in state.startIndex ..< state.endIndex {
        let status = state[index]
        if status.isSuccessful {
            indexes.insert(index)
        } else {
            cleanedUp.append(status)
        }
    }

    return ([.removal(of: indexes)], cleanedUp)
}

let IdleProcessingDelay = TimeInterval(2.0)

fileprivate class ActivityStatusesState {
    // MARK: - State
    private var state = [ActivityStatus]()

    // MARK: - Input
    lazy var input = BindingTarget<ActivityStatus>(on: scheduler, lifetime: lifetime) { [weak self] in
        self?.processInput($0)
    }

    // MARK: - Output
    var output: Signal<([ActivityStatus], [CollectionViewUpdate]), NoError> { return outputPipe.output }

    // MARK: - Infrastucture
    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()
    private var outputPipe = Signal<([ActivityStatus], [CollectionViewUpdate]), NoError>.pipe()
    private let inputReceivedPipe = Signal<Void, NoError>.pipe()

    // MARK: - Processing
    private let onCollectProcessors: [StateProcessor] = [collapseIntoSuccess]
    private let idleDelayedProcessors: [StateProcessor] = [cleanUpSuccessful]

    private func processInput(_ status: ActivityStatus) {
        inputReceivedPipe.input.send(value: ())

        var state = self.state
        var updateGroups = [[CollectionViewUpdate]]()

        func apply(_ updateAndState: ([CollectionViewUpdate], [ActivityStatus])?) {
            guard let (update, newState) = updateAndState else {
                return
            }
            state = newState
            updateGroups.append(update)
        }

        apply(collect(status, state))

        for process in onCollectProcessors {
            apply(process(state))
        }

        guard updateGroups.count > 0 else {
            return
        }

        let update = updateGroups.count == 1 ? updateGroups.first! : [.fullRefresh]
        self.state = state
        outputPipe.input.send(value: (state, update))
    }

    private func applyIdleDelayedProcessors() {
        var state = self.state
        var updateGroups = [[CollectionViewUpdate]]()

        func apply(_ updateAndState: ([CollectionViewUpdate], [ActivityStatus])?) {
            guard let (update, newState) = updateAndState else {
                return
            }
            state = newState
            updateGroups.append(update)
        }

        for process in idleDelayedProcessors {
            apply(process(state))
        }

        let update = updateGroups.count == 1 ? updateGroups.first! : [.fullRefresh]
        self.state = state
        outputPipe.input.send(value: (state, update))
    }

    // MARK: - Set up
    init() {
        let idleDelayTarget = BindingTarget<Void>(on: scheduler, lifetime: lifetime) { [weak self] _ in
            self?.applyIdleDelayedProcessors()
        }
        self.lifetime += idleDelayTarget <~ inputReceivedPipe.output.debounce(IdleProcessingDelay, on: scheduler).logEvents(identifier: "idleDelayTarget", events: [.value])
    }
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

