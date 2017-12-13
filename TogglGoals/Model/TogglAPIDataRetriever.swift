//
//  TogglAPIDataRetriever.swift
//  TogglGoals
//
//  Created by David Dávila on 13.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

typealias ReadProjectAction = Action<ProjectID, Property<Project?>, NoError>
typealias ReadReportAction = Action<ProjectID, Property<TwoPartTimeReport?>, NoError>

protocol TogglAPIDataRetriever: class {
    var apiCredential: BindingTarget<TogglAPICredential?> { get }
    var twoPartReportPeriod: BindingTarget<TwoPartTimeReportPeriod> { get }
}
