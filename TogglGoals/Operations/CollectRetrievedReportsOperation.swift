//
//  CollectRetrievedReportsOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class CollectRetrievedReportsOperation: Operation {
    private var _networkRetrieveReportsOperation: NetworkRetrieveReportsOperation?
    private var networkRetrieveReportsOperation: NetworkRetrieveReportsOperation? {
        get {
            if _networkRetrieveReportsOperation == nil {
                for operation in dependencies {
                    if let reportsOperation = operation as? NetworkRetrieveReportsOperation {
                        _networkRetrieveReportsOperation = reportsOperation
                    }
                }
            }
            return _networkRetrieveReportsOperation
        }
    }

    internal var collectedReports = Dictionary<Int64, TimeReport>()

    override func main() {
        guard !isCancelled else {
            return
        }

        guard networkRetrieveReportsOperation != nil else {
            return
        }

        let operation = networkRetrieveReportsOperation!

        if let reports = operation.model {
            for (projectId, report) in reports {
                collectedReports[projectId] = report
            }
        }
    }
}
