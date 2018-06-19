//
//  RetrieveReportsCacheAction.swift
//  TogglGoals
//
//  Created by David Dávila on 19.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

typealias RetrieveReportsCacheAction = Action<(), IndexedTwoPartTimeReports?, NoError>
func makeRetrieveReportsCacheAction() -> RetrieveReportsCacheAction {
    return RetrieveReportsCacheAction {
        print("would retrieve reports from cache")
        return SignalProducer.empty
    }
}
