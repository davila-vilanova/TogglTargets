//
//  CollectionOperation.swift
//  TogglGoals
//
//  Created by David Davila on 09.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class CollectionOperation<DependentOperation: Operation>: Operation {
    var collectionClosure: ((Set<DependentOperation>)->())?

    override func main() {
        guard !isCancelled else {
            return
        }
        guard let collectionClosure = self.collectionClosure else {
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
