//
//  ProjectsByGoals.swift
//  TogglGoals
//
//  Created by David Davila on 22.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct ProjectsByGoals {
    var projects: Dictionary<Int64, Project>! {
        didSet {
            let projectIds = [Int64](projects.keys)
            self.sortedProjectIds = projectIds.sorted(by: areGoalsInIncreasingOrder)
        }
    }
    var sortedProjectIds: [Int64]! {
        didSet {
            let indexOfFirstProjectWithoutGoal = sortedProjectIds.binarySearch { (projectId) -> Bool in
                hasGoal(projectId)
            }
            idsOfProjectsWithGoals = sortedProjectIds.prefix(indexOfFirstProjectWithoutGoal)
            idsOfProjectsWithoutGoals = sortedProjectIds.suffix(sortedProjectIds.count - indexOfFirstProjectWithoutGoal)
        }
    }
    var idsOfProjectsWithGoals: ArraySlice<Int64>!
    var idsOfProjectsWithoutGoals: ArraySlice<Int64>!
    
    typealias ProjectIdHasGoalFunction = (Int64) -> Bool
    let hasGoal: ProjectIdHasGoalFunction
    typealias ProjectIdsGoalsAreInIncreasingOrderFunction = (Int64, Int64) -> Bool
    let areGoalsInIncreasingOrder: ProjectIdsGoalsAreInIncreasingOrderFunction
    
    init(projects: Dictionary<Int64, Project>, hasGoal: @escaping ProjectIdHasGoalFunction,         areGoalsInIncreasingOrder: @escaping ProjectIdsGoalsAreInIncreasingOrderFunction) {
        self.hasGoal = hasGoal
        self.areGoalsInIncreasingOrder = areGoalsInIncreasingOrder
        defer { self.projects = projects }
    }
}

extension ProjectsByGoals {
    enum Section: Int {
        case withGoal = 0
        case withoutGoal = 1
    }
    
    func project(for indexPath: IndexPath) -> Project? {
        let projectIds: ArraySlice<Int64>
        switch indexPath.section {
        case 0: projectIds = idsOfProjectsWithGoals
        case 1: projectIds = idsOfProjectsWithoutGoals
        default: return nil
        }
        
        let projectId = projectIds[indexPath.item + projectIds.startIndex]
        return projects[projectId]
    }
    
    func indexPath(for indexInSortedProjects: Int) -> IndexPath? {
        guard indexInSortedProjects >= 0, indexInSortedProjects < sortedProjectIds.endIndex else {
            return nil
        }
        let section: Int, slice: ArraySlice<Int64>
        if indexInSortedProjects < idsOfProjectsWithGoals.endIndex {
            section = SectionIndex.projectsWithGoals.rawValue
            slice = idsOfProjectsWithGoals
        } else {
            section = SectionIndex.projectsWithoutGoals.rawValue
            slice = idsOfProjectsWithoutGoals
        }
        let item = indexInSortedProjects - slice.startIndex
        return IndexPath(item: item, section: section)
    }
}

extension ProjectsByGoals {
    func moveProjectAfterAddition(of newGoal: TimeGoal) -> (IndexPath, IndexPath)? {
        guard let oldIndex = sortedProjectIds.index(of: newGoal.projectId),
        let oldIndexPath = indexPath(for: oldIndex) else {
            return nil
        }
        let newIndex = sortedProjectIds.binarySearch { (projectId) -> Bool in
            return areGoalsInIncreasingOrder(projectId, newGoal.projectId)
        }
        guard let newIndexPath = indexPath(for: newIndex) else {
            return nil
        }
        return (oldIndexPath, newIndexPath)
    }
}

extension Collection {
    /// Finds such index N that predicate is true for all elements up to
    /// but not including the index N, and is false for all elements
    /// starting with index N.
    /// Behavior is undefined if there is no such N.
    func binarySearch(predicate: (Iterator.Element) -> Bool) -> Index {
        var low = startIndex
        var high = endIndex
        while low != high {
            let mid = index(low, offsetBy: distance(from: low, to: high)/2)
            if predicate(self[mid]) {
                low = index(after: mid)
            } else {
                high = mid
            }
        }
        return low
    }
}
