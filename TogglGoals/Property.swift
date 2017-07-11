//
//  UpdateHandler.swift
//  TogglGoals
//
//  Created by David Davila on 28.01.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

// Identity hence class
internal class Property<T> {
    fileprivate typealias UpdateObserver = ((Property<T>) -> ())
    fileprivate typealias ObserverToken = UUID

    private var _value: T
    internal var value: T {
        set (newValue) {
            _value = newValue
            notifyOfUpdate()
        }
        get {
            return _value
        }
    }

    var collectionUpdateClue: CollectionUpdateClue?
    
    func setCollectionValue(_ newValue: T, updateClue: CollectionUpdateClue) {
        self.collectionUpdateClue = updateClue
        self.value = newValue
    }

    internal private(set) var isInvalidated = false

    private var updateObservers = Dictionary<ObserverToken, UpdateObserver>()

    internal init(value: T) {
        self._value = value
    }

    deinit {
        invalidate()
    }

    internal func invalidate() {
        guard isInvalidated == false else {
            return
        }
        isInvalidated = true
        notifyOfUpdate()
    }

    fileprivate func observeUpdates(_ observer: @escaping UpdateObserver) -> ObserverToken {
        let token = generateObservationToken()
        updateObservers[token] = observer
        return token
    }

    fileprivate func stopObserving(_ token: ObserverToken) {
        updateObservers[token] = nil
    }

    fileprivate func setValue(_ value: T, skipUpdateNotification skipToken: ObserverToken) {
        self._value = value
        var s = Set<ObserverToken>()
        s.insert(skipToken)
        notifyOfUpdate(skipTokens: s)
    }

    private func notifyOfUpdate(skipTokens: Set<ObserverToken> = Set<ObserverToken>()) {
        for (token, observer) in updateObservers {
            if !skipTokens.contains(token) {
                observer(self)
            }
        }
    }

    private func generateObservationToken() -> ObserverToken {
        return UUID()
    }
}

fileprivate func describeUnwrappedOrNil(_ value: Any?) -> String {
    let valueDescription: String

    if let unwrappedValue = value {
        valueDescription = "\(unwrappedValue)"
    } else {
        valueDescription = "nil"
    }

    return valueDescription
}

extension Property: CustomDebugStringConvertible {
    var debugDescription: String {
        return "Property(value=\(describeUnwrappedOrNil(value)))"
    }
}

internal class ObservedProperty<T> {
    internal typealias ValueObserver = ((ObservedProperty<T>) -> ())

    internal typealias InvalidationObserver = (() -> ())

    internal private(set) weak var original: Property<T>?
    internal var isInvalidated: Bool {
        get {
            if let p = original {
                return p.isInvalidated
            } else {
                return true
            }
        }
    }

    private var observerToken: Property<T>.ObserverToken?
    private var valueObserver: ValueObserver?
    private var invalidationObserver: InvalidationObserver?
    private var queue: OperationQueue
    
    internal init(original: Property<T>,
                  queue: OperationQueue = OperationQueue.main,
                  valueObserver: @escaping ValueObserver,
                  invalidationObserver: @escaping InvalidationObserver = { }) {
        self.queue = queue

        guard !original.isInvalidated else {
            callback { invalidationObserver() }
            return
        }
        self.original = original
        self.valueObserver = valueObserver
        self.invalidationObserver = invalidationObserver
        self.observerToken = original.observeUpdates({ [weak self] (property) in
            guard let s = self else {
                return
            }
            if property.isInvalidated {
                s.callback {
                    s.invalidationObserver?()
                }
                s.unobserve()
            } else {
                s.callback {
                    s.valueObserver?(s)
                }
            }
        })
    }

    internal func unobserve() {
        if let p = original, let t = observerToken {
            p.stopObserving(t)
        }
        original = nil
        observerToken = nil
        valueObserver = nil
        invalidationObserver = nil
    }

    @discardableResult
    internal func reportImmediately() -> ObservedProperty<T> {
        if isInvalidated {
            callback { [weak self] in
                self?.invalidationObserver?()
            }
        } else {
            callback { [weak self] in
                guard let s = self else { return }
                s.valueObserver?(s)
            }
        }
        return self
    }

    deinit {
        unobserve()
    }
    
    private func callback(_ closure: @escaping () -> Void) {
        self.queue.addOperation(closure)
    }
}

extension ObservedProperty: CustomDebugStringConvertible {
    var debugDescription: String {
        return "ObservedProperty(original=\(describeUnwrappedOrNil(original)))"
    }
}

struct CollectionUpdateClue {
    let addedItems: Set<IndexPath>?
    let removedItems: Set<IndexPath>?
    let movedItems: Dictionary<IndexPath, IndexPath>?
    
    init(itemMovedFrom from: IndexPath, to: IndexPath) {
        movedItems = Dictionary<IndexPath, IndexPath>()
        movedItems![from] = to

        addedItems = nil
        removedItems = nil
    }
}
