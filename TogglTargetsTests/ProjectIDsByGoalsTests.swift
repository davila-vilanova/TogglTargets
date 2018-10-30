//
//  ProjectIDsByGoalsTests.swift
//  TogglGoalsTests
//
//  Created by David Dávila on 07.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

fileprivate let withGoal = ProjectIDsByTimeTargets.Section.withGoal.rawValue
fileprivate let withoutGoal = ProjectIDsByTimeTargets.Section.withoutGoal.rawValue

class ProjectIDsByGoalsTests: XCTestCase {

    let idsByGoals = ProjectIDsByTimeTargets(sortedProjectIDs: [897, 1243, 6103, 321407, 23, 0, 1432075, 12, 400],
                                       countOfProjectsWithGoals: 4)

    func testCountOfProjectsWithoutGoals() {
        XCTAssertEqual(idsByGoals.countOfProjectsWithoutGoals, 5)
    }

    func testEquality() {
        let a = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)
        let b = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)
        XCTAssertTrue(a == b)
        XCTAssertFalse(a != b)
    }

    func testNonEqualityByDifferingOrder() {
        let a = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)
        let b = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 2], countOfProjectsWithGoals: 2)
        XCTAssertTrue(a != b)
        XCTAssertFalse(a == b)
    }

    func testNonEqualityByDifferingCount() {
        let a = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)
        let b = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 1)
        XCTAssertTrue(a != b)
        XCTAssertFalse(a == b)
    }

    func testIndexPathGeneration() {
        XCTAssertEqual(idsByGoals.indexPath(forElementAt: 0), IndexPath(item: 0, section: withGoal))
        XCTAssertEqual(idsByGoals.indexPath(forElementAt: 1), IndexPath(item: 1, section: withGoal))
        XCTAssertEqual(idsByGoals.indexPath(forElementAt: 3), IndexPath(item: 3, section: withGoal))
        XCTAssertEqual(idsByGoals.indexPath(forElementAt: 4), IndexPath(item: 0, section: withoutGoal))
        XCTAssertEqual(idsByGoals.indexPath(forElementAt: 5), IndexPath(item: 1, section: withoutGoal))
        XCTAssertEqual(idsByGoals.indexPath(forElementAt: 8), IndexPath(item: 4, section: withoutGoal))
    }

    func testIndexPathInterpretation() {
        XCTAssertEqual(idsByGoals.projectId(for: IndexPath(item: 1, section: withGoal)), 1243)
        XCTAssertEqual(idsByGoals.projectId(for: IndexPath(item: 2, section: withoutGoal)), 1432075)
    }
}

fileprivate let SetupFailure = "Test setup failure: "
fileprivate let SetupFailureNilIndexedGoals = "\(SetupFailure)indexedGoals and projectId must not be nil"
fileprivate let SetupFailureNonMatchingProjectId = "\(SetupFailure)if a newGoal is provided, newGoal's projectId must match provided projectId"
fileprivate let SetupFailureNilIdsByGoals = "\(SetupFailure)idsByGoals must not be nil"
fileprivate let SetupFailureNilProjectId = "\(SetupFailure)after calling setupForProjectId(_, newGoal:) projectId must not be nil"

class ProjectIDsByGoalsUpdateTests: XCTestCase {
    var indexedGoals: ProjectIndexedGoals?
    var projectIDs: [ProjectID]?
    var idsByGoals: ProjectIDsByTimeTargets?

    var projectId: ProjectID?
    var oldGoal: TimeTarget?
    var newGoal: TimeTarget?
    var newIndexedGoals: ProjectIndexedGoals?

    typealias GoalUpdate = ProjectIDsByTimeTargets.Update.GoalUpdate

    // Updates the values of projectId, oldGoal, newGoal and newIndexedGoals
    func setUpForProjectId(_ projectId: ProjectID, newGoal: TimeTarget?) {
        guard let oldIndexedGoals = indexedGoals else {
            XCTFail(SetupFailureNilIndexedGoals)
            return
        }
        guard newGoal == nil || newGoal!.projectId == projectId else {
            XCTFail(SetupFailureNonMatchingProjectId)
            return
        }

        self.projectId = projectId
        self.newGoal = newGoal
        oldGoal = oldIndexedGoals[projectId]
        newIndexedGoals = {
            var t = oldIndexedGoals
            t[projectId] = newGoal
            return t
        }()
    }

    override func setUp() {
        super.setUp()
        indexedGoals = [ 71 : TimeTarget(for: 71, hoursTarget: 10, workWeekdays: WeekdaySelection.exceptWeekend),
                         25 : TimeTarget(for: 25, hoursTarget: 20, workWeekdays: WeekdaySelection.wholeWeek),
                         90 : TimeTarget(for: 90, hoursTarget: 50, workWeekdays: WeekdaySelection.exceptWeekend),
                         48 : TimeTarget(for: 48, hoursTarget: 30, workWeekdays: WeekdaySelection.exceptWeekend) ]
        projectIDs = [30, 12, 25, 89, 22, 48, 71, 60]

        idsByGoals = ProjectIDsByTimeTargets(projectIDs: projectIDs!, goals: indexedGoals!)

        projectId = nil
        oldGoal = nil
        newGoal = nil
        newIndexedGoals = nil
    }

    func testInitialization() {
        guard let idsByGoals = idsByGoals else {
            XCTFail(SetupFailureNilIdsByGoals)
            return
        }
        XCTAssertEqual(idsByGoals.sortedProjectIDs, [48, 25, 71, 89, 60, 30, 22, 12])
        XCTAssertEqual(idsByGoals.countOfProjectsWithGoals, 3)
    }

    func testEditExistingGoal() {
        guard let idsByGoals = idsByGoals else {
            XCTFail(SetupFailureNilIdsByGoals)
            return
        }
        guard let indexedGoals = indexedGoals else {
            XCTFail(SetupFailureNilIndexedGoals)
            return
        }

        setUpForProjectId(48, newGoal: TimeTarget(for: 48, hoursTarget: 15, workWeekdays: WeekdaySelection.exceptWeekend))
        guard let projectId = projectId else {
            XCTFail(SetupFailureNilProjectId)
            return
        }

        let goalUpdate = GoalUpdate.forGoalChange(involving: newGoal,
                                                  for: projectId,
                                                  within: indexedGoals,
                                                  affecting: idsByGoals)
        guard let update = goalUpdate else {
            XCTFail()
            return
        }

        let indexChange = update.indexChange
        XCTAssertEqual(indexChange.old, 0)
        XCTAssertEqual(indexChange.new, 1)
        XCTAssertEqual(update.computeNewCount(from: idsByGoals), 3)

        let newIdsByGoals = update.apply(to: idsByGoals)
        XCTAssertEqual(newIdsByGoals.sortedProjectIDs, [25, 48, 71, 89, 60, 30, 22, 12])
        XCTAssertEqual(newIdsByGoals.countOfProjectsWithGoals, 3)

        XCTAssertEqual(idsByGoals.indexPath(forElementAt: indexChange.old), IndexPath(item: 0, section: withGoal))
        XCTAssertEqual(newIdsByGoals.indexPath(forElementAt: indexChange.new), IndexPath(item: 1, section: withGoal))
    }


    func testDeleteGoal() {
        guard let idsByGoals = idsByGoals else {
            XCTFail(SetupFailureNilIdsByGoals)
            return
        }
        guard let indexedGoals = indexedGoals else {
            XCTFail(SetupFailureNilIndexedGoals)
            return
        }

        setUpForProjectId(25, newGoal: nil)
        guard let projectId = projectId else {
            XCTFail(SetupFailureNilProjectId)
            return
        }

        let goalUpdate = GoalUpdate.forGoalChange(involving: newGoal,
                                                  for: projectId,
                                                  within: indexedGoals,
                                                  affecting: idsByGoals)
        guard let update = goalUpdate else {
            XCTFail()
            return
        }

        let indexChange = update.indexChange
        XCTAssertEqual(indexChange.old, 1)
        XCTAssertEqual(indexChange.new, 5)
        XCTAssertEqual(update.computeNewCount(from: idsByGoals), 2)

        let newIdsByGoals = update.apply(to: idsByGoals)
        XCTAssertEqual(newIdsByGoals.sortedProjectIDs, [48, 71, 89, 60, 30, 25, 22, 12])
        XCTAssertEqual(newIdsByGoals.countOfProjectsWithGoals, 2)

        XCTAssertEqual(idsByGoals.indexPath(forElementAt: indexChange.old), IndexPath(item: 1, section: withGoal))
        XCTAssertEqual(newIdsByGoals.indexPath(forElementAt: indexChange.new), IndexPath(item: 3, section: withoutGoal))
    }

    func testCreateGoal() {
        guard let idsByGoals = idsByGoals else {
            XCTFail(SetupFailureNilIdsByGoals)
            return
        }
        guard let indexedGoals = indexedGoals else {
            XCTFail(SetupFailureNilIndexedGoals)
            return
        }

        setUpForProjectId(22, newGoal: TimeTarget(for: 22, hoursTarget: 16, workWeekdays: WeekdaySelection.exceptWeekend))
        guard let projectId = projectId else {
            XCTFail(SetupFailureNilProjectId)
            return
        }

        let goalUpdate = GoalUpdate.forGoalChange(involving: newGoal,
                                                  for: projectId,
                                                  within: indexedGoals,
                                                  affecting: idsByGoals)

        guard let update = goalUpdate else {
            XCTFail()
            return
        }

        let indexChange = update.indexChange
        XCTAssertEqual(indexChange.old, 6)
        XCTAssertEqual(indexChange.new, 2)
        XCTAssertEqual(update.computeNewCount(from: idsByGoals), 4)

        let newIdsByGoals = update.apply(to: idsByGoals)
        XCTAssertEqual(newIdsByGoals.sortedProjectIDs, [48, 25, 22, 71, 89, 60, 30, 12])
        XCTAssertEqual(newIdsByGoals.countOfProjectsWithGoals, 4)

        XCTAssertEqual(idsByGoals.indexPath(forElementAt: indexChange.old), IndexPath(item: 3, section: withoutGoal))
        XCTAssertEqual(newIdsByGoals.indexPath(forElementAt: indexChange.new), IndexPath(item: 2, section: withGoal))
    }
}
