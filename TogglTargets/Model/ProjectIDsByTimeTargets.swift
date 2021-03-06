//
//  ProjectIDsByTimeTargets.swift
//  TogglTargets
//
//  Created by David Dávila on 05.12.17.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// Encloses a sorted array of project IDs, ordered primarily by descending time target size and a count of projects
/// that have time targets associated with them.
struct ProjectIDsByTimeTargets {
    /// The sorted collection of project IDs
    let sortedProjectIDs: [ProjectID]

    // Count of projects, from among those whose IDs are included in `sortedProjectIDs`,
    /// that have time targets associated with them.
    let countOfProjectsWithTimeTargets: Int

    /// Represents an empty `ProjectIDsByTimeTargets` value
    static let empty = ProjectIDsByTimeTargets(sortedProjectIDs: [ProjectID](), countOfProjectsWithTimeTargets: 0)

    /// Represents a full or incremental update to a `ProjectIDsByTimeTargets` value.
    enum Update {
        /// An update that entails a full refresh.
        case full(ProjectIDsByTimeTargets)

        /// An update that affects a single time target.
        case singleTimeTarget(SingleTimeTargetUpdate)
    }

    /// Represents an update that consists of a reorder operation for a single project ID and possibly an increment or
    /// decrement of the count of projects associated with time targets.
    enum SingleTimeTargetUpdate {

        /// Represents the update resulting from the creation of one time target.
        case create(IndexChange)

        /// Represents the update resulting from the removal of one time target.
        case remove(IndexChange)

        /// Represents the update resulting from the change of the values of a single time target.
        case update(IndexChange)

        /// Returns the `IndexChange` resulting form this update.
        var indexChange: IndexChange {
            switch self {
            case .create(let change): return change
            case .remove(let change): return change
            case .update(let change): return change
            }
        }

        /// Returns the new count of project IDs associated with time targets after this update.
        ///
        /// - parameters:
        ///   - idsByTimeTargets: The `ProjectIDsByTimeTargets` value immediately previous to this update.
        ///
        /// - returns: The count of project IDs associated with time targets resulting from applying
        ///            this udpate to `idsByTimeTarget`
        func computeNewCount(from idsByTimeTargets: ProjectIDsByTimeTargets) -> Int {
            let oldCount = idsByTimeTargets.countOfProjectsWithTimeTargets
            switch self {
            case .create: return oldCount + 1
            case .remove: return oldCount - 1
            case .update: return oldCount
            }
        }

        /// Returns the result of applying this update to a `ProjectIDsByTimeTargets` value.
        ///
        /// - parameters:
        ///   - idsByTimeTargets: The `ProjectIDsByTimeTargets` value immediately previous to this update.
        ///
        /// - returns: A `ProjectIDsByTimeTargets` value resulting of applying this update to `idsByTimeTargets`
        func apply(to idsByTimeTargets: ProjectIDsByTimeTargets) -> ProjectIDsByTimeTargets {
            var sortedIDs = idsByTimeTargets.sortedProjectIDs
            let item = sortedIDs.remove(at: indexChange.old)
            sortedIDs.insert(item, at: indexChange.new)
            return ProjectIDsByTimeTargets(sortedProjectIDs: sortedIDs,
                                           countOfProjectsWithTimeTargets: computeNewCount(from: idsByTimeTargets))
        }

        /// Generates the update corresponding to creating, deleting or updating the time target associated with a
        /// project ID
        ///
        /// - parameters:
        ///   - newTimeTarget: The value of the affected time target after the update. Pass `nil` for a target deletion.
        ///   - projectId: The project ID whose time target will be created, deleted or updated.
        ///                This ID must be included in the project IDs associated with the `idsByTimeTargets` argument.
        ///                If it is not, this call will return nil.
        ///   - timeTargetsPreChange: The `ProjectIdIndexedTimeTargets` value previous to updating the time target.
        ///   - idsByTimeTargets: The `ProjectIDsByTimeTargets` value that will be affected by this update.
        ///
        ///   - note: The old time target value will be extracted from `timeTargetsPreChange`
        ///
        /// - returns: The update corresponding to the change in the time target associated with `projectId`,
        ///              `nil` if `projectId` is not included in `idsByTimeTargets`
        static func forTimeTargetChange(involving newTimeTarget: TimeTarget?,
                                        for projectId: ProjectID,
                                        within timeTargetPreChange: ProjectIdIndexedTimeTargets,
                                        affecting idsByTimeTargets: ProjectIDsByTimeTargets)
            -> SingleTimeTargetUpdate? {
                let currentSortedIDs = idsByTimeTargets.sortedProjectIDs
                let newlySortedIDs = currentSortedIDs
                    .sorted(by: makeAreProjectIDsInIncreasingOrderFunction(
                        for: timeTargetPreChange.updatingValue(newTimeTarget, forKey: projectId)))

                guard let oldIndex = currentSortedIDs.index(of: projectId),
                    let newIndex = newlySortedIDs.index(of: projectId) else {
                        return nil
                }

                let oldTimeTarget = timeTargetPreChange[projectId]
                let indexChange = IndexChange(old: oldIndex, new: newIndex)
                if (oldTimeTarget == nil) && (newTimeTarget != nil) {
                    return .create(indexChange)
                } else if (oldTimeTarget != nil) && (newTimeTarget == nil) {
                    return .remove(indexChange)
                } else {
                    return .update(indexChange)
                }
        }
    }

    /// Represents the effect of a reorder operation affecting a single project ID.
    struct IndexChange {
        /// The index of the affected project ID in the pre-update array of sorted project IDs.
        let old: Int

        /// The index of the affected project ID in the post-update array of sorted project IDs.
        let new: Int
    }
}

extension ProjectIDsByTimeTargets {
    /// Initializes a `ProjectIDsByTimeTargets` value with the provided projectIDs sorted by the descending size
    /// of the provided time targets. To guarantee stable order as long as the provided project IDs are unique,
    /// if two time targets are considered of equivalent size the order will be determined by project ID descending.
    ///
    /// - parameters:
    ///   - projectIDs: The IDs to sort by the provided time targets. All IDs must be unique.
    ///   - timeTargets: The time targets upon which to base the primary ordering of the IDs.
    init(projectIDs: [ProjectID], timeTargets: ProjectIdIndexedTimeTargets) {
        let sortedIDs = projectIDs.sorted(by: makeAreProjectIDsInIncreasingOrderFunction(for: timeTargets))
        let countWithTimeTargets = sortedIDs.prefix { timeTargets[$0] != nil }.count
        self.init(sortedProjectIDs: sortedIDs, countOfProjectsWithTimeTargets: countWithTimeTargets)
    }

    /// Initializes a `ProjectIDsByTimeTargets` value with the provided projectIDs sorted by the descending size
    /// of the provided time targets. To guarantee stable order, if two time targets are considered of equivalent size
    /// the order will be determined by project ID descending.
    ///
    /// - parameters:
    ///   - projectIDs: The IDs to sort by the provided time targets.
    ///   - timeTargets: The time targets upon which to base the primary ordering of the IDs.
    init(projectIDs: Set<ProjectID>, timeTargets: ProjectIdIndexedTimeTargets) {
        self.init(projectIDs: [ProjectID](projectIDs), timeTargets: timeTargets)
    }
}

extension ProjectIDsByTimeTargets: Equatable {
    public static func == (lhs: ProjectIDsByTimeTargets, rhs: ProjectIDsByTimeTargets) -> Bool {
        return (lhs.sortedProjectIDs == rhs.sortedProjectIDs) &&
            (lhs.countOfProjectsWithTimeTargets == rhs.countOfProjectsWithTimeTargets)
    }
}

extension ProjectIDsByTimeTargets {
    /// The count of project IDs without a time target associated to them.
    var countOfProjectsWithoutTimeTargets: Int {
        let count = sortedProjectIDs.count - countOfProjectsWithTimeTargets
        assert(count >= 0)
        return count
    }
}

extension ProjectIDsByTimeTargets.Update {
    var timeTargetUpdate: ProjectIDsByTimeTargets.SingleTimeTargetUpdate? {
        switch self {
        case .singleTimeTarget(let timeTargetUpdate): return timeTargetUpdate
        default: return nil
        }
    }

    var fullyUpdated: ProjectIDsByTimeTargets? {
        switch self {
        case .full(let projectIDsByTimeTargets): return projectIDsByTimeTargets
        default: return nil
        }
    }

    var isSingleTimeTargetUpdate: Bool {
        switch self {
        case .singleTimeTarget: return true
        default: return false
        }
    }
}

extension ProjectIDsByTimeTargets {
    /// Denotes a plausible set of sections in which a list of projects ordered by time targets could be organized
    enum Section: Int {
        /// The section for projects that have time targets associated to them.
        case withTimeTargets = 0
        /// The section for projects that have no time targets associated to them.
        case withoutTimeTargets = 1

        /// The count of sections in this enum.
        static var count = 2
    }

    /// Returns the project ID addressed by an `IndexPath` based on the sections represented by `Section`
    ///
    /// - parameters: indexPath: An `IndexPath` value whose `section` property matches the raw value of one of the
    ///               sections defined as cases of `Section` and whose `item` value addresses the index of the project
    ///               project within that section.
    ///
    /// - returns: The addressed project ID or `nil` if the value of `indexPath.section` does not match any of the cases
    ///            defined in `Section` or if the value of `indexPath.item` exceeds the boundaries of the ordinal
    ///            indexes of the project IDs in that section.
    func projectId(for indexPath: IndexPath) -> ProjectID? {
        guard let section = Section(rawValue: indexPath.section) else {
            return nil
        }

        let index: Int

        switch section {
        case .withTimeTargets:
            index = indexPath.item
            guard index <= countOfProjectsWithTimeTargets else {
                return nil
            }
        case .withoutTimeTargets:
            index = indexPath.item + countOfProjectsWithTimeTargets
        }
        guard index < sortedProjectIDs.count else {
            return nil
        }
        return sortedProjectIDs[index]
    }

    /// Returns the `IndexPath` at which the project ID corresponding to the provided index can be addressed.
    ///
    /// - parameters: index: An index that must be within the bounds of the array of sorted project IDs
    ///
    /// - returns: The `IndexPath` enclosing the section and index corresponding to the project ID at `index`
    ///            or `nil` if the index is outside of the bounds of the array of sorted project IDs.
    ///            The index path's `section` property will be based on the sections defined by `Section`
    ///            and its `item` property will indicate the project's order within that section.
    func indexPath(forElementAt index: Int) -> IndexPath? {
        guard index >= 0, index < sortedProjectIDs.count else {
            return nil
        }
        let section: Section, item: Int
        if index < countOfProjectsWithTimeTargets {
            section = .withTimeTargets
            item = index
        } else {
            section = .withoutTimeTargets
            item = index - countOfProjectsWithTimeTargets
        }
        return IndexPath(item: item, section: section.rawValue)
    }

    func indexPath(for projectId: ProjectID) -> IndexPath? {
        guard let foundIndex = sortedProjectIDs.index(of: projectId) else {
            return nil
        }
        return indexPath(forElementAt: foundIndex)
    }

    func numberOfItems(in section: Section) -> Int {
        switch section {
        case .withTimeTargets: return countOfProjectsWithTimeTargets
        case .withoutTimeTargets: return countOfProjectsWithoutTimeTargets
        }
    }

    func indexPathOfLastItem(in section: Section) -> IndexPath {
        return IndexPath(item: numberOfItems(in: section) - 1, section: section.rawValue)
    }

    func isIndexPathOfLastItemInSection(_ indexPath: IndexPath) -> Bool {
        guard let section = Section(rawValue: indexPath.section) else {
            return false
        }
        return indexPath == indexPathOfLastItem(in: section)
    }
}

/// Makes a function that can be used as input to `Array<ProjectID>.sort(by:)` and will determine the order of the
/// project IDs by whether they have a time target or not and the size of the target (the length of time associated with
/// it). IDs will be ordered with those that have a timeTarget first ordered by descending timeTarget size. To guarantee
/// stable order as long as the IDs are unique, if two targets are considered of equivalent size (including the case in
/// which they are both missing) the order will be determined by project ID descending.
///
/// - parameters:
///   - timeTargets: The `ProjectIndexedTimeTargets` that the returned function will use as context.
///
/// - returns: A function that determines the relative order of two project IDs.
private func makeAreProjectIDsInIncreasingOrderFunction(for timeTargets: ProjectIdIndexedTimeTargets)
    -> (ProjectID, ProjectID) -> Bool {
        return { (idL, idR) -> Bool in
            let left = timeTargets[idL]
            let right = timeTargets[idR]
            if let left = left, let right = right {
                // the larger time target comes first
                return left > right
            } else if left != nil, right == nil {
                // a target is more targeter than a no target
                return true
            } else if left == nil, right == nil {
                // order needs to be stable, so use project ID which is assumed to be unique
                return idL > idR
            } else {
                return false
            }
        }
}
