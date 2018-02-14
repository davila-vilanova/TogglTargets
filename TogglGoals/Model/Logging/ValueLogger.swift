//
//  ValueLogger.swift
//  TogglGoals
//
//  Created by David Dávila on 14.02.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

extension Signal {
    public func logValues(_ identifier: String) -> Signal<Value, Error> {
        return logEvents(identifier: identifier, events: [.value], logger: cleanEventLog)
    }
}

extension SignalProducer {
    public func logValues(_ identifier: String) -> SignalProducer<Value, Error> {
        return logEvents(identifier: identifier, events: [.value], logger: cleanEventLog)
    }
}

fileprivate func cleanEventLog(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
    print("[\(identifier)] \(event)")
}
