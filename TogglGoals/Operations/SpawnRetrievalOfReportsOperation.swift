//
//  SpawnRetrievalOfReportsOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class SpawnRetrievalOfReportsOperation: Operation {
    private var _NetworkRetrieveProfileOperation: NetworkRetrieveProfileOperation?
    private var NetworkRetrieveProfileOperation: NetworkRetrieveProfileOperation? {
        get {
            if _NetworkRetrieveProfileOperation == nil {
                for operation in dependencies {
                    if let profileOperation = operation as? NetworkRetrieveProfileOperation {
                        _NetworkRetrieveProfileOperation = profileOperation
                    }
                }
            }
            return _NetworkRetrieveProfileOperation
        }
    }

    private let credential: TogglAPICredential
    private let CollectRetrievedReportsOperation: CollectRetrievedReportsOperation

    init(credential: TogglAPICredential, CollectRetrievedReportsOperation: CollectRetrievedReportsOperation) {
        self.credential = credential
        self.CollectRetrievedReportsOperation = CollectRetrievedReportsOperation
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        guard NetworkRetrieveProfileOperation != nil else {
            return
        }

        let operation = NetworkRetrieveProfileOperation!

        if let workspaces = operation.model?.1 {
            for w in workspaces {
                let op = NetworkRetrieveReportsOperation(credential: credential, workspaceId: w.id)
                CollectRetrievedReportsOperation.addDependency(op)
                OperationQueue.current?.addOperation(op)
            }
        } else if let error = operation.error {
            // TODO
            print(error)
        } else {
            
        }
    }
}
