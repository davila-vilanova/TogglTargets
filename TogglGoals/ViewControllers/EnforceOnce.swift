//
//  EnforceOnce.swift
//  TogglGoals
//
//  Created by David Dávila on 04.02.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift


fileprivate let scheduler = QueueScheduler(name: "EnforceOnceScheduler")
fileprivate var seenTokens = Set<String>()

internal func enforceOnce(for token: String, _ action: @escaping () -> Void) {
    scheduler.schedule {
        guard !seenTokens.contains(token) else {
            assert(false, "Action must be executed exactly once for caller with token=\(token).")
            return
        }
        action()
        seenTokens.insert(token)
    }
}
