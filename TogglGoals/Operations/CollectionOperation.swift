//
//  CollectionOperation.swift
//  TogglGoals
//
//  Created by David Davila on 09.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class CollectionOperation<DependentOperation: Operation>: Operation {
    private let collectionClosure: ((Set<DependentOperation>)->())

    init(_ collectionClosure: @escaping ((Set<DependentOperation>)->())) {
        self.collectionClosure = collectionClosure
    }

    override func main() {
        guard !isCancelled else {
            return
        }
        var collectableOperations = Set<DependentOperation>()
        for dependency in dependencies {
            if let collectableOperation = dependency as? DependentOperation {
                collectableOperations.insert(collectableOperation)
            }
        }
        collectionClosure(collectableOperations)
    }
}
