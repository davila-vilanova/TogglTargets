//
//  CollectionUpdateClue.swift
//  TogglGoals
//
//  Created by David Dávila on 25.08.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct CollectionUpdateClue {
    let addedItems: Set<IndexPath>?
    let removedItems: Set<IndexPath>?
    let movedItems: Dictionary<IndexPath, IndexPath>?

    init(itemMovedFrom from: IndexPath, to: IndexPath) {
        movedItems = Dictionary<IndexPath, IndexPath>()
        movedItems![from] = to

        addedItems = nil
        removedItems = nil
    }
}
