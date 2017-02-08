//
//  CollectRetrievedProjectsOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class CollectRetrievedProjectsOperation: Operation {
    private var _networkRetrieveProjectsOperation: NetworkRetrieveProjectsOperation?
    private var networkRetrieveProjectsOperation: NetworkRetrieveProjectsOperation? {
        get {
            if _networkRetrieveProjectsOperation == nil {
                for operation in dependencies {
                    if let projectsOperation = operation as? NetworkRetrieveProjectsOperation {
                        _networkRetrieveProjectsOperation = projectsOperation
                    }
                }
            }
            return _networkRetrieveProjectsOperation
        }
    }

    internal var collectedProjects = Array<Project>()

    override init() {
        super.init()
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        guard networkRetrieveProjectsOperation != nil else {
            return
        }

        let operation = networkRetrieveProjectsOperation!

        if let projects = operation.model {
            collectedProjects.append(contentsOf: projects)
        }
    }
}
