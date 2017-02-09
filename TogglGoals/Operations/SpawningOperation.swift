//
//  SpawningOperation.swift
//  TogglGoals
//
//  Created by David Davila on 08.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class SpawningOperation<InputModel, OutputModel, CollectionOperation: Operation>: Operation {
    private var inputRetrievalOperation: TogglAPIAccessOperation<[InputModel]> // whichever operation will/did load all the items for each of which a new operation must be spawned
    private let outputCollectionOperation: Operation
    private let outputRetrievalOperationSpawner: ( (InputModel)-> TogglAPIAccessOperation<OutputModel>? )

    init(inputRetrievalOperation: TogglAPIAccessOperation<[InputModel]>,
         outputCollectionOperation: Operation,
         outputRetrievalOperationSpawner: @escaping ( (InputModel)-> TogglAPIAccessOperation<OutputModel>? )) {

        self.inputRetrievalOperation = inputRetrievalOperation
        self.outputCollectionOperation = outputCollectionOperation
        self.outputRetrievalOperationSpawner = outputRetrievalOperationSpawner

        super.init()

        addDependency(inputRetrievalOperation)
        self.outputCollectionOperation.addDependency(self)
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
                if let op = outputRetrievalOperationSpawner(input) {
                    self.outputCollectionOperation.addDependency(op)
                    OperationQueue.current?.addOperation(op)
                }
            }
        }
    }
}
