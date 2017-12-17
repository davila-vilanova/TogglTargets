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
    /// The sorted collection of project IDs
    let sortedProjectIDs: [ProjectID]

    // Count of projects, from among those whose IDs are included in `sortedProjectIDs`,
    /// that have goals associated with them.
    let countOfProjectsWithGoals: Int

    /// Represents a full or incremental update to a `ProjectIDsByGoals` value.
    enum Update {
        /// An update that entails a full refresh.
        case full(ProjectIDsByGoals)

        /// An update that affects a single goal.
        case singleGoal(GoalUpdate)

        /// Represents an update that consists of a reorder operation for a single project ID
        /// and possibly an increment or decrement of the count of projects associated with goals.
        enum GoalUpdate {

            /// Represents the effect of a reorder operation affecting a single project ID.
            struct IndexChange {
                /// The index of the affected project ID in the pre-update array of sorted project IDs.
                let old: Int

                /// The index of the affected project ID in the post-update array of sorted project IDs.
                let new: Int
            }

            /// Represents the update resulting from the creation of one goal.
            case create(IndexChange)

            /// Represents the update resulting from the removal of one goal.
            case remove(IndexChange)

            /// Represents the update resulting from the change of the values of a single goal.
            case update(IndexChange)

            /// Returns the `IndexChange` resulting form this update.
            var indexChange: IndexChange {
                switch self {
                case .create(let change): return change
                case .remove(let change): return change
                case .update(let change): return change
                }
            }

            /// Returns the new count of project IDs associated with goals after this update.
            ///
            /// - parameters:
            ///   - idsByGoals: The `ProjectIDsByGoals` value immediately previous to this update.
            ///
            /// - returns: The count of project IDs associated with goals resulting from applying
            ///            this udpate to `idsByGoals`
            func computeNewCount(from idsByGoals: ProjectIDsByGoals) -> Int {
                let oldCount = idsByGoals.countOfProjectsWithGoals
                switch self {
                case .create: return oldCount + 1
                case .remove: return oldCount - 1
                case .update: return oldCount
                }
            }

            /// Returns the result of applying this update to a `ProjectIDsByGoals` value.
            ///
            /// - parameters:
            ///   - idsByGoals: The `ProjectIDsByGoals` value immediately previous to this update.
            ///
            ///   - returns: A `ProjectIDsByGoals` value resulting of applying this update to `idsByGoals`
            func apply(to idsByGoals: ProjectIDsByGoals) -> ProjectIDsByGoals {
                var sortedIDs = idsByGoals.sortedProjectIDs
                let item = sortedIDs.remove(at: indexChange.old)
                sortedIDs.insert(item, at: indexChange.new)
                return ProjectIDsByGoals(sortedProjectIDs: sortedIDs,
                                         countOfProjectsWithGoals: computeNewCount(from: idsByGoals))
            }

            /// Generates the update corresponding to creating, deleting or updating the goal associated
            /// with a project ID
            ///
            /// - parameters:
            ///   - idsByGoals: The `ProjectIDsByGoals` value that will be affected by this update.
            ///   - projectId: The project ID whose goal will be created, deleted or updated.
            ///                This ID must be included in the project IDs associated with the `idsByGoals`
            ///                argument. If it is not, this call will return nil.
            ///  - oldGoal: The value of the affected goal previous to the update. Pass `nil` for a goal creation.
            ///  - newGoal: The value of the affected goal after the update. Pass `nil` for a goal deletion.
            ///  - newIndexedGoals: The `ProjectIndexedGoals` value that results from updating the goal.
            ///                     This value must differ from the indexed goals used to sort the IDs enclosed
            ///                     in the provided `idsByGoals` by no more than one goal. The return value is
            ///                     otherwise not defined.
            ///
            ///  - note: The new goal value will be extracted from `newIndexedGoals`
            ///
            ///   - returns: The update corresponding to the change in the goal associated with `projectId`,
            ///              `nil` if `projectId` is not included in `idsByGoals`
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

    /// Represents an empty `ProjectIDsByGoals` value
    static let empty = ProjectIDsByGoals(sortedProjectIDs: [ProjectID](), countOfProjectsWithGoals: 0)
}

extension ProjectIDsByGoals {
    /// Initializes a `ProjectIDsByGoals` value with the provided projectIDs sorted by the descending size
    /// of the provided goals. To guarantee stable order as long as the provided project IDs are unique,
    /// if two goals are considered of equivalent size the order will be determined by project ID descending.
    ///
    /// - parameters:
    ///   - projectIDs: The IDs to sort by the provided goals. All IDs must be unique.
    ///   - goals: The goals upon which to base the primary ordering of the IDs.
    init(projectIDs: [ProjectID], goals: ProjectIndexedGoals) {
        let sortedIDs = projectIDs.sorted(by: makeAreProjectIDsInIncreasingOrderFunction(for: goals))
        let countWithGoals = sortedIDs.prefix { goals[$0] != nil }.count
        self.init(sortedProjectIDs: sortedIDs, countOfProjectsWithGoals: countWithGoals)
    }

    /// Initializes a `ProjectIDsByGoals` value with the provided projectIDs sorted by the descending size
    /// of the provided goals. To guarantee stable order, if two goals are considered of equivalent size the
    /// order will be determined by project ID descending.
    ///
    /// - parameters:
    ///   - projectIDs: The IDs to sort by the provided goals.
    ///   - goals: The goals upon which to base the primary ordering of the IDs.
    init(projectIDs: Set<ProjectID>, goals: ProjectIndexedGoals) {
        self.init(projectIDs: [ProjectID](projectIDs), goals: goals)
    }
}

extension ProjectIDsByGoals: Equatable {
    public static func ==(lhs: ProjectIDsByGoals, rhs: ProjectIDsByGoals) -> Bool {
        return (lhs.sortedProjectIDs == rhs.sortedProjectIDs) &&
            (lhs.countOfProjectsWithGoals == rhs.countOfProjectsWithGoals)
    }
}

extension ProjectIDsByGoals {
    /// The count of project IDs without a goal associated to them.
    var countOfProjectsWithoutGoals: Int {
        let count = sortedProjectIDs.count - countOfProjectsWithGoals
        assert(count >= 0)
        return count
    }
}

extension ProjectIDsByGoals {
    /// Denotes a plausible set of sections in which a list of projects ordered by goals could be organized
    enum Section: Int {
        /// The section for projects that have goals associated to them.
        case withGoal = 0
        /// The section for projects that have no goals associated to them.
        case withoutGoal = 1

        /// The count of sections in this enum.
        static var count = 2
    }

    /// Returns the project ID addressed by an `IndexPath` based on the sections represented by `Section`
    ///
    /// - parameters: indexPath: An `IndexPath` value whose `section` property matches the raw value of one of
    ///               the sections defined as cases of `Section` and whose `item` value addresses the index of
    ///               the project within that section.
    ///
    /// - returns: The addressed project ID or `nil` if the value of `indexPath.section` does not match any of
    ///            the cases defined in `Section` or if the value of `indexPath.item` exceeds the boundaries
    ///            of the ordinal indexes of the project IDs in that section.
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

/// Makes a function that can be used as input to `Array<ProjectID>.sort(by:)` and will determine the
/// order of the project IDs by whether they have a goal or not and the size of the goal. IDs will be ordered
/// with those that have a goal first ordered by descending goal size. To guarantee stable order as long as
/// the IDs are unique, if two goals are considered of equivalent size (including the case in which they are
/// both missing) the order will be determined by project ID descending.
///
/// - parameters:
///   - goals: The `ProjectIndexedGoals` that the returned function will use as context.
///
/// - returns: A function that determines the relative order of two project IDs.
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
                // order needs to be stable, so use project ID
                return idL > idR
            } else {
                return false
            }
        }
}