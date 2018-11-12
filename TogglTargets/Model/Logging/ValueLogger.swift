//
//  ValueLogger.swift
//  TogglTargets
//
//  Created by David Dávila on 14.02.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

extension Signal {
    public func logValues(_ identifier: String, logger: @escaping EventLogger = logEventMinimally) -> Signal<Value, Error> {
        return logEvents(identifier: identifier, events: [.value], logger: logEventMinimally)
    }
}

extension SignalProducer {
    public func logValues(_ identifier: String, logger: @escaping EventLogger = logEventMinimally)
        -> SignalProducer<Value, Error> {
            return logEvents(identifier: identifier, events: [.value], logger: logger)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter
}()

public func logEventMinimally(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
    print("\(dateFormatter.string(from: Date())): [\(identifier)] \(event)")
}
