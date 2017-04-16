//
//  CollectionOperation.swift
//  TogglGoals
//
//  Created by David Davila on 09.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class CollectionOperation<DependentOperation: Operation, CollectedOutput>: Operation {

    var collectedOutput: CollectedOutput?

    var collectionClosure: (()->CollectedOutput)?

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
        collectedOutput = collectOutput(collectableOperations)
    }

    internal func collectOutput(_ collectableOperations: Set<DependentOperation>) -> CollectedOutput? {
        return collectedOutput
    }
}
