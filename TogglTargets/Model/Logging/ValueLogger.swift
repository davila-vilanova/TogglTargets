//
//  ValueLogger.swift
//  TogglTargets
//
//  Created by David Dávila on 14.02.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter
}()

extension Signal {
    public func logValues(_ identifier: String, logger: @escaping EventLogger = cleanEventLog) -> Signal<Value, Error> {
        return logEvents(identifier: identifier, events: [.value], logger: cleanEventLog)
    }
}

extension SignalProducer {
    public func logValues(_ identifier: String, logger: @escaping EventLogger = cleanEventLog) -> SignalProducer<Value, Error> {
        return logEvents(identifier: identifier, events: [.value], logger: logger)
    }
}

public func cleanEventLog(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
    print("\(dateFormatter.string(from: Date())): [\(identifier)] \(event)")
}
