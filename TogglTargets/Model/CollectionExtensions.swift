//
//  CollectionExtensions.swift
//  TogglTargets
//
//  Created by David Dávila on 10.02.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation

extension Dictionary {
    func updatingValue(_ value: Dictionary.Value?, forKey key: Dictionary.Key) -> Dictionary<Key, Value> {
        var updated = self
        if let value = value {
            updated[key] = value
        } else {
            updated.removeValue(forKey: key)
        }
        return updated
    }
}
