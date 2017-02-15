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
    fileprivate typealias UpdateObserver = ((T?, Bool) -> ())
    fileprivate typealias ObserverToken = UUID

    private var _value: T?
    internal var value: T? {
        set (newValue) {
            _value = newValue
            notifyOfUpdate()
        }
        get {
            return _value
        }
    }

    internal private(set) var isInvalidated = false

    private var updateObservers = Dictionary<ObserverToken, UpdateObserver>()

    internal init(value: T?) {
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

    fileprivate func setValue(_ value: T?, skipUpdateNotification skipToken: ObserverToken) {
        self._value = value
        var s = Set<ObserverToken>()
        s.insert(skipToken)
        notifyOfUpdate(skipTokens: s)
    }

    private func notifyOfUpdate(skipTokens: Set<ObserverToken> = Set<ObserverToken>()) {
        for (token, observer) in updateObservers {
            if !skipTokens.contains(token) {
                observer(isInvalidated ? nil : value, isInvalidated)
            }
        }
    }

    private func generateObservationToken() -> ObserverToken {
        return UUID()
    }
}

internal class ObservedProperty<T> {
    internal typealias ValueObserver = ((T?) -> ())
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

    internal init(original: Property<T>,
                  valueObserver: @escaping ValueObserver,
                  invalidationObserver: @escaping InvalidationObserver = { }) {
        guard !original.isInvalidated else {
            invalidationObserver()
            return
        }
        self.original = original
        self.valueObserver = valueObserver
        self.invalidationObserver = invalidationObserver
        self.observerToken = original.observeUpdates({ [weak self] (value, invalidated) in
            if invalidated {
                self?.invalidationObserver?()
                self?.unobserve()
            }
            self?.valueObserver?(value)
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

    internal func reportImmediately() -> ObservedProperty<T> {
        if isInvalidated {
            invalidationObserver?()
        } else {
            valueObserver?(original?.value)
        }
        return self
    }

    deinit {
        unobserve()
    }
}
