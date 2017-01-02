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

/* Encapsulates a piece of data that may be immediately available, may be available in the future, or a combination (receives updates over time)
 */
class AsynchronousResult<ResultDataType> {
    // MARK: - Consumer
    var state: AsynchronousResultState = .waitingForFirstResult

    var isFinal: Bool {
        get {
            return state == .completed
        }

        internal set {
            // TODO
        }
    }

    private(set) var data: ResultDataType?
    private(set) var finalError: Error?

    var availabilityCallback: ((AsynchronousResult<ResultDataType>) -> ())? {
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

    internal func commitResultAsFinal(_ final: Bool) {
        // TODO
    }

//    internal func setResult(result: AsynchronousResult, dataUnwrapper: ((Any?) -> ResultDataType?)) {
//        setResult(data: dataUnwrapper(result.data), error: result.finalError, final: result.isFinal);
//    }

    // MARK: - Private
    let condition = NSCondition()
    var didSetNewResult = false

    private func callResultAvailabilityCallback() {
        if let callback = availabilityCallback {
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
