//
//  ProjectIDsByGoals.swift
//  TogglGoals
//
//  Created by David Dávila on 05.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

/// Encloses a sorted array of project IDs, ordered primarily by descending goal size
/// and a count of projects that have goals associated with them.
struct ProjectIDsByGoals {
    /// The sorted collection of array IDs
    let sortedProjectIDs: [ProjectID]

    // Count of projects, from among those whose IDs are included in sortedProjectIDs,
    /// that have goals associated with them
    let countOfProjectsWithGoals: Int

    /// Represents a full or incremental update to a ProjectIDsByGoals
    enum Update {
        /// Represents a full update that entails a full refresh
        case full(ProjectIDsByGoals)

        /// Represents an update that consists of a single move operation and possibly an
        /// increment or decrement of the count of projects associated with goals
        case createGoal(GoalUpdate)

        enum GoalUpdate {
            struct IndexChange {
                let old: Int
                let new: Int
            }

            case create(IndexChange)
            case remove(IndexChange)
            case update(IndexChange)

            var indexChange: IndexChange {
                switch self {
                case .create(let change): return change
                case .remove(let change): return change
                case .update(let change): return change
                }
            }

            func computeNewCount(from idsByGoals: ProjectIDsByGoals) -> Int {
                let oldCount = idsByGoals.countOfProjectsWithGoals
                switch self {
                case .create: return oldCount + 1
                case .remove: return oldCount - 1
                case .update: return oldCount
                }
            }

            func apply(to pre: ProjectIDsByGoals) -> ProjectIDsByGoals {
                var sortedIDs = pre.sortedProjectIDs
                let item = sortedIDs.remove(at: indexChange.old)
                sortedIDs.insert(item, at: indexChange.new)
                return ProjectIDsByGoals(sortedProjectIDs: sortedIDs,
                                         countOfProjectsWithGoals: computeNewCount(from: pre))
            }

            static func forGoalChange(affecting idsByGoals: ProjectIDsByGoals,
                                      for projectId: ProjectID,
                                      from oldGoal: Goal?,
                                      producing newIndexedGoals: ProjectIndexedGoals) -> Update.GoalUpdate?  {
                let currentSortedIDs = idsByGoals.sortedProjectIDs
                let newlySortedIDs = currentSortedIDs
                    .sorted(by: makeAreProjectIDsInIncreasingOrderFunction(for: newIndexedGoals))

                guard let oldIndex = currentSortedIDs.index(of: projectId),
                    let newIndex = newlySortedIDs.index(of: projectId) else {
                        return nil
                }
                let newGoal = newIndexedGoals[projectId]

                let indexChange = IndexChange(old: oldIndex, new: newIndex)
                if (oldGoal == nil) && (newGoal != nil) {
                    return .create(indexChange)
                } else if (oldGoal != nil) && (newGoal == nil) {
                    return .remove(indexChange)
                } else {
                    return .update(indexChange)
                }
            }
        }
    }

    static let empty = ProjectIDsByGoals(sortedProjectIDs: [ProjectID](), countOfProjectsWithGoals: 0)
}

extension ProjectIDsByGoals {
    init(projectIDs: [ProjectID], goals: ProjectIndexedGoals) {
        let sortedIDs = projectIDs.sorted(by: makeAreProjectIDsInIncreasingOrderFunction(for: goals))
        let countWithGoals = sortedIDs.prefix { goals[$0] != nil }.count
        self.init(sortedProjectIDs: sortedIDs, countOfProjectsWithGoals: countWithGoals)
    }
}

extension ProjectIDsByGoals: Equatable {
    public static func ==(lhs: ProjectIDsByGoals, rhs: ProjectIDsByGoals) -> Bool {
        return (lhs.sortedProjectIDs == rhs.sortedProjectIDs) &&
            (lhs.countOfProjectsWithGoals == rhs.countOfProjectsWithGoals)
    }
}

extension ProjectIDsByGoals {
    var countOfProjectsWithoutGoals: Int {
        let count = sortedProjectIDs.count - countOfProjectsWithGoals
        assert(count >= 0)
        return count
    }
}

extension ProjectIDsByGoals {

    enum Section: Int {
        case withGoal = 0
        case withoutGoal = 1

        static var count = 2
    }

    func projectId(for indexPath: IndexPath) -> ProjectID? {
        guard let section = Section(rawValue: indexPath.section) else {
            return nil
        }

        let index: Int

        switch section {
        case .withGoal:
            index = indexPath.item
            guard index <= countOfProjectsWithGoals else {
                return nil
            }
        case .withoutGoal:
            index = indexPath.item + countOfProjectsWithGoals
        }
        guard index < sortedProjectIDs.count else {
            return nil
        }
        return sortedProjectIDs[index]
    }

    func indexPath(forElementAt index: Int) -> IndexPath? {
        guard index >= 0, index < sortedProjectIDs.count else {
            return nil
        }
        let section: Section, item: Int
        if index < countOfProjectsWithGoals {
            section = .withGoal
            item = index
        } else {
            section = .withoutGoal
            item = index - countOfProjectsWithGoals
        }
        return IndexPath(item: item, section: section.rawValue)
    }
}

fileprivate func makeAreProjectIDsInIncreasingOrderFunction(for goals: ProjectIndexedGoals)
    -> (ProjectID, ProjectID) -> Bool {
        return { (idL, idR) -> Bool in
            let left = goals[idL]
            let right = goals[idR]
            if let left = left, let right = right {
                // the larger goal comes first
                return left > right
            } else if left != nil, right == nil {
                // a goal is more goaler than a no goal
                return true
            } else if left == nil, right == nil {
                // order needs to be deterministic, so use project ID
                return idL > idR
            } else {
                return false
            }
        }
}
