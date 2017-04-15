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
    let outputCollectionOperation: CollectionOperation<SpawnedOperationType>

    private var queue: OperationQueue? {
        get {
            return OperationQueue.current
        }
    }

    init(inputRetrievalOperation: TogglAPIAccessOperation<[InputArrayElement]>) {
        self.inputRetrievalOperation = inputRetrievalOperation
        self.outputCollectionOperation = CollectionOperation<SpawnedOperationType>()

        super.init()

        addDependency(inputRetrievalOperation)

        self.outputCollectionOperation.addDependency(self)
        outputCollectionOperation.collectionClosure = collectOutput
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
                let spawnedOps = makeOperationsToSpawn(from: input)
                for spawnedOp in spawnedOps {
                    self.outputCollectionOperation.addDependency(spawnedOp)
                    queueOperation(spawnedOp)
                }
            }
        }
    }
  
    func makeOperationsToSpawn(from inputElement: InputArrayElement) -> [SpawnedOperationType] {
        return [SpawnedOperationType]()
    }
    
    func collectOutput(from spawnedOperations: Set<SpawnedOperationType>) {
        
    }
    
    private func queueOperation(_ op: Operation) {
        queue?.addOperation(op)
    }
}
