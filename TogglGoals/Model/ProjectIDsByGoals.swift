//
//  ProjectIDsByGoals.swift
//  TogglGoals
//
//  Created by David Dávila on 05.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct ProjectIDsByGoals {
    let sortedProjectIDs: [ProjectID]
    let countOfProjectsWithGoals: Int

    enum Update {
        case fullRefresh(ProjectIDsByGoals)
        case move(MoveUpdate)
    }

    struct MoveUpdate {
        let oldIndex: Int
        let newIndex: Int
        let newCountOfProjectsWithGoals: Int

        init(from oldIndex: Int, to newIndex: Int, newCount: Int) {
            self.oldIndex = oldIndex
            self.newIndex = newIndex
            self.newCountOfProjectsWithGoals = newCount
        }
    }

    static let empty = ProjectIDsByGoals(sortedProjectIDs: [ProjectID](), countOfProjectsWithGoals: 0)
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

enum Section: Int {
    case withGoal = 0
    case withoutGoal = 1

    static var count = 2
}

extension ProjectIDsByGoals {
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

extension ProjectIDsByGoals {
    func applying(_ update: MoveUpdate) -> ProjectIDsByGoals {
        var sortedIDs = sortedProjectIDs
        let item = sortedIDs.remove(at: update.oldIndex)
        sortedIDs.insert(item, at: update.newIndex)
        return ProjectIDsByGoals(sortedProjectIDs: sortedIDs,
                                 countOfProjectsWithGoals: update.newCountOfProjectsWithGoals)
    }
}

extension ProjectIDsByGoals {
    init(projectIDs: [ProjectID], goals: ProjectIndexedGoals) {
        let sortedIDs = projectIDs.sorted(by: makeAreProjectIDsInIncreasingOrderFunction(for: goals))
        let countWithGoals = sortedIDs.prefix { goals[$0] != nil }.count
        self.init(sortedProjectIDs: sortedIDs, countOfProjectsWithGoals: countWithGoals)
    }

    struct Error: Swift.Error { }

    enum ChangeType {
        case create
        case delete
        case update
    }

    struct ModifyGoalOutput {
        let moveUpdate: ProjectIDsByGoals.MoveUpdate
        let changeType: ProjectIDsByGoals.ChangeType
        let indexedGoals: ProjectIndexedGoals
        let projectIDsByGoals: ProjectIDsByGoals
    }

    func afterEditingGoal(_ newGoal: Goal?, for projectId: ProjectID, in indexedGoals: ProjectIndexedGoals)
        throws -> ModifyGoalOutput {
            guard let oldIndex = sortedProjectIDs.index(of: projectId) else {
                throw Error()
            }
            let oldGoal = indexedGoals[projectId]
            let newIndexedGoals: ProjectIndexedGoals = {
                var t = ProjectIndexedGoals(minimumCapacity: indexedGoals.count)
                t.merge(indexedGoals, uniquingKeysWith: { (goal, _) in goal })
                if let newGoal = newGoal {
                    t[projectId] = newGoal
                } else {
                    t.removeValue(forKey: projectId)
                }
                return t
            }()
            let newlySortedIDs = sortedProjectIDs
                .sorted(by: makeAreProjectIDsInIncreasingOrderFunction(for: newIndexedGoals))
            guard let newIndex = newlySortedIDs.index(of: projectId) else {
                throw Error()
            }
            let (changeType, countIncrement) = { () -> (ChangeType, Int) in
                if (oldGoal == nil) && (newGoal != nil) {
                    return (.create, +1)
                } else if (oldGoal != nil) && (newGoal == nil) {
                    return (.delete, -1)
                } else {
                    return (.update, 0)
                }
            }()
            let newCount = countOfProjectsWithGoals + countIncrement
            let moveUpdate = ProjectIDsByGoals.MoveUpdate(from: oldIndex, to: newIndex,
                                                          newCount: newCount)
            let newProjectIDsByGoals = ProjectIDsByGoals(sortedProjectIDs: newlySortedIDs, countOfProjectsWithGoals: newCount)
            return ModifyGoalOutput(moveUpdate: moveUpdate,
                                    changeType: changeType,
                                    indexedGoals: newIndexedGoals,
                                    projectIDsByGoals: newProjectIDsByGoals)
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
