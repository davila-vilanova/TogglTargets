//
//  SpawnRetrievalOfProjectsOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class SpawnRetrievalOfProjectsOperation: Operation {
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
    private let collectRetrievedProjectsOperation: CollectRetrievedProjectsOperation

    init(credential: TogglAPICredential, collectRetrievedProjectsOperation: CollectRetrievedProjectsOperation) {
        self.credential = credential
        self.collectRetrievedProjectsOperation = collectRetrievedProjectsOperation
        super.init()
        self.collectRetrievedProjectsOperation.addDependency(self)
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
                let op = NetworkRetrieveProjectsOperation(credential: credential, workspaceId: w.id)
                collectRetrievedProjectsOperation.addDependency(op)
                OperationQueue.current?.addOperation(op)
            }
        } else if let error = operation.error {
            // TODO
            print(error)
        } else {

        }
    }
}
