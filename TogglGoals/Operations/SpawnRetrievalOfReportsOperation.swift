//
//  SpawnRetrievalOfReportsOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class SpawnRetrievalOfReportsOperation: Operation {
    private var _retrieveWorkspacesOperation: NetworkRetrieveWorkspacesOperation?
    private var retrieveWorkspacesOperation: NetworkRetrieveWorkspacesOperation? {
        get {
            if _retrieveWorkspacesOperation == nil {
                for operation in dependencies {
                    if let workspacesOperation = operation as? NetworkRetrieveWorkspacesOperation {
                        _retrieveWorkspacesOperation = workspacesOperation
                    }
                }
            }
            return _retrieveWorkspacesOperation
        }
    }


    private let credential: TogglAPICredential
    private let collectRetrievedReportsOperation: CollectRetrievedReportsOperation

    init(credential: TogglAPICredential, collectRetrievedReportsOperation: CollectRetrievedReportsOperation) {
        self.credential = credential
        self.collectRetrievedReportsOperation = collectRetrievedReportsOperation
        super.init()
        self.collectRetrievedReportsOperation.addDependency(self)
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        guard retrieveWorkspacesOperation != nil else {
            return
        }

        let operation = retrieveWorkspacesOperation!

        if let workspaces = operation.model {
            for w in workspaces {
                let op = NetworkRetrieveReportsOperation(credential: credential, workspaceId: w.id)
                collectRetrievedReportsOperation.addDependency(op)
                OperationQueue.current?.addOperation(op)
            }
        } else if let error = operation.error {
            // TODO
            print(error)
        } else {
            
        }
    }
}
