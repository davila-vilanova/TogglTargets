//
//  AsynchronousResult.swift
//  TogglGoals
//
//  Created by David Davila on 25/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

enum AsynchronousResultState {
    case waitingForFirstResult, waitingForUpdate, completed
}

class AsynchronousResult<ResultDataType> {
    // MARK: - Consumer
    var state: AsynchronousResultState = .waitingForFirstResult

    private(set) var resultData: ResultDataType?
    private(set) var resultError: Error?

    var resultAvailabilityCallback: ((AsynchronousResult<ResultDataType>) -> ())? {
        didSet {
            if (state != .waitingForFirstResult) {
                callResultAvailabilityCallback()
            }
        }
    }

    // TODO: thread safety
    func blockAndWaitForResult() {
        // Blow up if on main thread
        assert(!Thread.current.isMainThread,
               "Calling \(#function) in the main thread is not allowed")

        // Return immediately if .completed
        if state == .completed {
            return;
        }

        // Wait for signal
        condition.lock()
        while !didSetNewResult {
            condition.wait()
        }
        didSetNewResult = false
        condition.unlock()
    }

    // MARK: - Producer
    internal func setResult(data: ResultDataType?, error: Error?, isFurtherUpdateExpected: Bool) {
        guard state != .completed else {
            return
        }

        if let d = data {
            resultData = d
            state = isFurtherUpdateExpected ? .waitingForUpdate : .completed
            newResultDidBecomeAvailable()
        } else if let e = error {
            resultError = e
            state = .completed
            newResultDidBecomeAvailable()
        }
    }

    // MARK: - Private
    let condition = NSCondition()
    var didSetNewResult = false

    private func callResultAvailabilityCallback() {
        if let callback = resultAvailabilityCallback {
            callback(self)
        }
    }

    private func newResultDidBecomeAvailable() {
        condition.lock()
        didSetNewResult = true
        condition.broadcast()
        condition.unlock()

        callResultAvailabilityCallback()
    }
}
