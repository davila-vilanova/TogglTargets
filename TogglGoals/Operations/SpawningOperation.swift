//
//  SpawningOperation.swift
//  TogglGoals
//
//  Created by David Davila on 08.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class SpawningOperation<InputArrayElement, SpawnedOperationOutput, SpawnedOperationType: Operation>: Operation {
    private var inputRetrievalOperation: TogglAPIAccessOperation<[InputArrayElement]> // whichever operation will/did load all the items for each of which a new operation must be spawned
    private let outputRetrievalSpawnedOperationsMaker: ( (InputArrayElement)-> [TogglAPIAccessOperation<SpawnedOperationOutput>] )
    private let outputCollectionOperation: Operation

    private var queue: OperationQueue? {
        get {
            return OperationQueue.current
        }
    }

    init(inputRetrievalOperation: TogglAPIAccessOperation<[InputArrayElement]>,
         spawnedOperationsMaker: @escaping (InputArrayElement) -> [TogglAPIAccessOperation<SpawnedOperationOutput>],
         collectionClosure: @escaping (Set<SpawnedOperationType>) -> ()) {

        self.inputRetrievalOperation = inputRetrievalOperation
        self.outputRetrievalSpawnedOperationsMaker = spawnedOperationsMaker
        self.outputCollectionOperation = CollectionOperation<SpawnedOperationType>(collectionClosure)

        super.init()

        addDependency(inputRetrievalOperation)
        self.outputCollectionOperation.addDependency(self)
        queueOperation(self.outputCollectionOperation)
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        if let error = inputRetrievalOperation.error {
            // TODO: error handling / propagation
            Swift.print(error)
        } else if let inputs = inputRetrievalOperation.model {
            for input in inputs {
                let spawnedOps = outputRetrievalSpawnedOperationsMaker(input)
                for spawnedOp in spawnedOps {
                    self.outputCollectionOperation.addDependency(spawnedOp)
                    queueOperation(spawnedOp)
                }
            }
        }
    }

    private func queueOperation(_ op: Operation) {
        queue?.addOperation(op)
    }
}
