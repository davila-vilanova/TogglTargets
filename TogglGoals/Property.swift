//
//  UpdateHandler.swift
//  TogglGoals
//
//  Created by David Davila on 28.01.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal enum PropertyState {
    case valid
    case invalid // e.g. "orphan"
}


// Identity hence class
internal class Property<T> {
    internal typealias UpdateObserver = ((T?, PropertyState) -> ())
    internal typealias ObserverToken = UUID

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

    internal var state = PropertyState.valid

    private var updateObservers = Dictionary<ObserverToken, UpdateObserver>()

    internal init(value: T?) {
        self._value = value
    }

    internal func observeUpdates(_ observer: @escaping UpdateObserver) -> ObserverToken {
        let token = generateObservationToken()
        updateObservers[token] = observer
        return token
    }

    internal func stopObserving(_ token: ObserverToken) {
        updateObservers[token] = nil
    }

    internal func setValue(_ value: T?, skipUpdateNotification skipToken: ObserverToken) {
        self._value = value
        var s = Set<ObserverToken>()
        s.insert(skipToken)
        notifyOfUpdate(skipTokens: s)
    }

    private func notifyOfUpdate(skipTokens: Set<ObserverToken> = Set<ObserverToken>()) {
        for (token, observer) in updateObservers {
            if !skipTokens.contains(token) {
                observer(self.value, self.state)
            }
        }
    }

    private func generateObservationToken() -> ObserverToken {
        return UUID()
    }
}

