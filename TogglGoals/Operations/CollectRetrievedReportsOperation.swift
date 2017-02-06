//
//  CollectRetrievedReportsOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class CollectRetrievedReportsOperation: Operation {
    private var _NetworkRetrieveReportsOperation: NetworkRetrieveReportsOperation?
    private var NetworkRetrieveReportsOperation: NetworkRetrieveReportsOperation? {
        get {
            if _NetworkRetrieveReportsOperation == nil {
                for operation in dependencies {
                    if let reportsOperation = operation as? NetworkRetrieveReportsOperation {
                        _NetworkRetrieveReportsOperation = reportsOperation
                    }
                }
            }
            return _NetworkRetrieveReportsOperation
        }
    }

    internal var collectedReports = Dictionary<Int64, TimeReport>()

    override func main() {
        guard !isCancelled else {
            return
        }

        guard NetworkRetrieveReportsOperation != nil else {
            return
        }

        let operation = NetworkRetrieveReportsOperation!

        if let reports = operation.model {
            for (projectId, report) in reports {
                collectedReports[projectId] = report
            }
        }
    }
}
