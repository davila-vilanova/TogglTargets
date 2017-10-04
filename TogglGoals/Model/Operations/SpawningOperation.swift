//
//  SpawningOperation.swift
//  TogglGoals
//
//  Created by David Davila on 08.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class SpawningOperation<InputArrayElement, CollectionOperation: Operation>: Operation {
    private var inputRetrievalOperation: TogglAPIAccessOperation<[InputArrayElement]> // whichever operation will/did load all the items for each of which a new operation must be spawned
    public let outputCollectionOperation: CollectionOperation

    private var queue: OperationQueue? {
        get {
            return OperationQueue.current
        }
    }

    init(inputRetrievalOperation: TogglAPIAccessOperation<[InputArrayElement]>) {
        self.inputRetrievalOperation = inputRetrievalOperation
        self.outputCollectionOperation = CollectionOperation()

        super.init()

        addDependency(inputRetrievalOperation)

        configureCollectionOperation()
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
                let spawnedOps = makeOperationsToSpawn(from: input)
                for spawnedOp in spawnedOps {
                    self.outputCollectionOperation.addDependency(spawnedOp)
                    queueOperation(spawnedOp)
                }
            }
        }
    }
  
    
    func configureCollectionOperation() {
        
    }
    
    func makeOperationsToSpawn(from inputElement: InputArrayElement) -> [Operation] {
        return [Operation]()
    }
    
    private func queueOperation(_ op: Operation) {
        queue?.addOperation(op)
    }
}
