//: Playground - noun: a place where people can play

import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = false

extension ProjectIDsByGoals: Equatable {
    public static func ==(lhs: ProjectIDsByGoals, rhs: ProjectIDsByGoals) -> Bool {
        return (lhs.sortedProjectIDs == rhs.sortedProjectIDs) &&
            (lhs.countOfProjectsWithGoals == rhs.countOfProjectsWithGoals)
    }
}

let p1 = ProjectIDsByGoals(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)

let p2 = ProjectIDsByGoals(sortedProjectIDs: [1, 3, 2], countOfProjectsWithGoals: 2)

p1 == p2
p1 != p2
