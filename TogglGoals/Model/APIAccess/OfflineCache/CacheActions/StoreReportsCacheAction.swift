//
//  StoreReportsCacheAction.swift
//  TogglGoals
//
//  Created by David Dávila on 19.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

typealias StoreReportsCacheAction = Action<IndexedTwoPartTimeReports?, (), NoError>
func makeStoreReportsCacheAction() -> StoreReportsCacheAction {
    return StoreReportsCacheAction { reports in
        if reports != nil {
            print("would store reports in cache")
        } else {
            print("would delete reports from cache")
        }
        return SignalProducer.empty // TODO
    }
}
