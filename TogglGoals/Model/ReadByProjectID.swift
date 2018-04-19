//
//  ReadByProjectID.swift
//  TogglGoals
//
//  Created by David Dávila on 16.04.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

/// Function which takes a project ID as input and returns a producer that
/// emits values over time corresponding to the project associated with that
/// project ID.
typealias ReadProject = (ProjectID) -> SignalProducer<Project?, NoError>

/// Function which takes a project ID as input and returns a producer that
/// emits values over time corresponding to the report associated with that
/// project ID.
typealias ReadReport = (ProjectID) -> SignalProducer<TwoPartTimeReport?, NoError>

/// Function which takes a project ID as input and returns a producer that
/// emits values over time corresponding to the goal associated with that
/// project ID.
///
/// - note: `nil` goal values represent a goal that does not exist yet or
///         that has been deleted.
typealias ReadGoal = (ProjectID) -> SignalProducer<Goal?, NoError>
