//
//  SpawningOperation.swift
//  TogglGoals
//
//  Created by David Davila on 08.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class SpawningOperation<InputModel, OutputModel, OutputRetriever: Operation>: Operation {
    private var inputRetrievalOperation: TogglAPIAccessOperation<[InputModel]> // whichever operation will/did load all the items for each of which a new operation must be spawned
    private let outputRetrievalOperationSpawner: ( (InputModel)-> [TogglAPIAccessOperation<OutputModel>] )
    private let outputCollectionOperation: Operation

    private var queue: OperationQueue? {
        get {
            return OperationQueue.current
        }
    }

    init(inputRetrievalOperation: TogglAPIAccessOperation<[InputModel]>,
         spawnOperationMaker: @escaping (InputModel) -> [TogglAPIAccessOperation<OutputModel>],
         collectionClosure: @escaping (Set<OutputRetriever>) -> ()) {

        self.inputRetrievalOperation = inputRetrievalOperation
        self.outputRetrievalOperationSpawner = spawnOperationMaker
        self.outputCollectionOperation = CollectionOperation<OutputRetriever>(collectionClosure)

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
                let spawnedOps = outputRetrievalOperationSpawner(input)
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
