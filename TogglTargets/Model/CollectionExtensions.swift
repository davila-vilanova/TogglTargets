//
//  CollectionExtensions.swift
//  TogglTargets
//
//  Created by David Dávila on 10.02.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation

extension Dictionary {

    /// Returns a copy of self dictionary substituting or inserting a value for a single key.
    ///
    /// - parameters:
    ///   - value: The value to substitute or insert for `key`.
    ///   - key: The key whose value to substitute or insert.
    ///
    /// - returns: A new dictionary that is identical to this except for the `value` of `key`.
    func updatingValue(_ value: Dictionary.Value?, forKey key: Dictionary.Key) -> [Key: Value] {
        var updated = self
        if let value = value {
            updated[key] = value
        } else {
            updated.removeValue(forKey: key)
        }
        return updated
    }
}
