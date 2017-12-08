//
//  ProjectIDsByGoalsTests.swift
//  TogglGoalsTests
//
//  Created by David Dávila on 07.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

fileprivate let withGoal = Section.withGoal.rawValue
fileprivate let withoutGoal = Section.withoutGoal.rawValue

class ProjectIDsByGoalsTests: XCTestCase {

    let idsByGoals = ProjectIDsByGoals(sortedProjectIDs: [897, 1243, 6103, 321407, 23, 0, 1432075, 12, 400],
                                       countOfProjectsWithGoals: 4)

    func testCountOfProjectsWithoutGoals() {
        XCTAssertEqual(idsByGoals.countOfProjectsWithoutGoals, 5)
    }

    func testEquality() {
        let a = ProjectIDsByGoals(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)
        let b = ProjectIDsByGoals(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)
        XCTAssertTrue(a == b)
        XCTAssertFalse(a != b)
    }

    func testNonEqualityByDifferingOrder() {
        let a = ProjectIDsByGoals(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)
        let b = ProjectIDsByGoals(sortedProjectIDs: [1, 2, 2], countOfProjectsWithGoals: 2)
        XCTAssertTrue(a != b)
        XCTAssertFalse(a == b)
    }

    func testNonEqualityByDifferingCount() {
        let a = ProjectIDsByGoals(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 2)
        let b = ProjectIDsByGoals(sortedProjectIDs: [1, 2, 3], countOfProjectsWithGoals: 1)
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

class ProjectIDsByGoalsUpdateTests: XCTestCase {
    var indexedGoals: ProjectIndexedGoals!
    var projectIDs: [ProjectID]!
    var idsByGoals: ProjectIDsByGoals!

    override func setUp() {
        super.setUp()
        indexedGoals = [ 71 : Goal(forProjectId: 71, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend),
                         25 : Goal(forProjectId: 25, hoursPerMonth: 20, workWeekdays: WeekdaySelection.wholeWeek),
                         90 : Goal(forProjectId: 90, hoursPerMonth: 50, workWeekdays: WeekdaySelection.exceptWeekend),
                         48 : Goal(forProjectId: 48, hoursPerMonth: 30, workWeekdays: WeekdaySelection.exceptWeekend) ]
        projectIDs = [30, 12, 25, 89, 22, 48, 71, 60]

        idsByGoals = ProjectIDsByGoals(projectIDs: projectIDs, goals: indexedGoals)
    }

    func testInitialization() {
        XCTAssertEqual(idsByGoals.sortedProjectIDs, [48, 25, 71, 89, 60, 30, 22, 12])
        XCTAssertEqual(idsByGoals.countOfProjectsWithGoals, 3)
    }

    func testEditExistingGoal() {
        let newGoal = Goal(forProjectId: 48, hoursPerMonth: 15, workWeekdays: WeekdaySelection.exceptWeekend)
        do {
            let output = try idsByGoals.afterEditingGoal(newGoal, for: 48, in: indexedGoals)
            XCTAssertEqual(output.projectIDsByGoals.sortedProjectIDs, [25, 48, 71, 89, 60, 30, 22, 12])
            XCTAssertEqual(output.projectIDsByGoals.countOfProjectsWithGoals, 3)

            XCTAssertEqual(output.moveUpdate.oldIndex, 0)
            XCTAssertEqual(output.moveUpdate.newIndex, 1)
            XCTAssertEqual(output.moveUpdate.newCountOfProjectsWithGoals, 3)

            XCTAssertEqual(output.changeType, .update)

            XCTAssertEqual(output.indexedGoals, [ 71 : Goal(forProjectId: 71, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend),
                                                  25 : Goal(forProjectId: 25, hoursPerMonth: 20, workWeekdays: WeekdaySelection.wholeWeek),
                                                  90 : Goal(forProjectId: 90, hoursPerMonth: 50, workWeekdays: WeekdaySelection.exceptWeekend),
                                                  48 : Goal(forProjectId: 48, hoursPerMonth: 15, workWeekdays: WeekdaySelection.exceptWeekend) ])

            XCTAssertEqual(idsByGoals.applying(output.moveUpdate), output.projectIDsByGoals)

            XCTAssertEqual(idsByGoals.indexPath(forElementAt: output.moveUpdate.oldIndex), IndexPath(item: 0, section: withGoal))
            XCTAssertEqual(output.projectIDsByGoals.indexPath(forElementAt: output.moveUpdate.newIndex), IndexPath(item: 1, section: withGoal))
        } catch {
            XCTFail()
        }
    }

    func testDeleteGoal() {
        do {
            let output = try idsByGoals.afterEditingGoal(nil, for: 25, in: indexedGoals)
            XCTAssertEqual(output.projectIDsByGoals.sortedProjectIDs, [48, 71, 89, 60, 30, 25, 22, 12])
            XCTAssertEqual(output.projectIDsByGoals.countOfProjectsWithGoals, 2)

            XCTAssertEqual(output.moveUpdate.oldIndex, 1)
            XCTAssertEqual(output.moveUpdate.newIndex, 5)
            XCTAssertEqual(output.moveUpdate.newCountOfProjectsWithGoals, 2)

            XCTAssertEqual(output.changeType, .delete)

            XCTAssertEqual(output.indexedGoals, [ 71 : Goal(forProjectId: 71, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend),
                                                  90 : Goal(forProjectId: 90, hoursPerMonth: 50, workWeekdays: WeekdaySelection.exceptWeekend),
                                                  48 : Goal(forProjectId: 48, hoursPerMonth: 30, workWeekdays: WeekdaySelection.exceptWeekend) ])

            XCTAssertEqual(idsByGoals.applying(output.moveUpdate), output.projectIDsByGoals)
            XCTAssertEqual(idsByGoals.indexPath(forElementAt: output.moveUpdate.oldIndex), IndexPath(item: 1, section: withGoal))
            XCTAssertEqual(output.projectIDsByGoals.indexPath(forElementAt: output.moveUpdate.newIndex), IndexPath(item: 3, section: withoutGoal))
        } catch {
            XCTFail()
        }
    }

    func testCreateGoal() {
        do {
            let newGoal = Goal(forProjectId: 22, hoursPerMonth: 16, workWeekdays: WeekdaySelection.exceptWeekend)
            let output = try idsByGoals.afterEditingGoal(newGoal, for: 22, in: indexedGoals)
            XCTAssertEqual(output.projectIDsByGoals.sortedProjectIDs, [48, 25, 22, 71, 89, 60, 30, 12])
            XCTAssertEqual(output.projectIDsByGoals.countOfProjectsWithGoals, 4)

            XCTAssertEqual(output.moveUpdate.oldIndex, 6)
            XCTAssertEqual(output.moveUpdate.newIndex, 2)
            XCTAssertEqual(output.moveUpdate.newCountOfProjectsWithGoals, 4)

            XCTAssertEqual(output.changeType, .create)

            XCTAssertEqual(output.indexedGoals, [ 71 : Goal(forProjectId: 71, hoursPerMonth: 10, workWeekdays: WeekdaySelection.exceptWeekend),
                                                  25 : Goal(forProjectId: 25, hoursPerMonth: 20, workWeekdays: WeekdaySelection.wholeWeek),
                                                  90 : Goal(forProjectId: 90, hoursPerMonth: 50, workWeekdays: WeekdaySelection.exceptWeekend),
                                                  22 : Goal(forProjectId: 22, hoursPerMonth: 16, workWeekdays: WeekdaySelection.exceptWeekend),
                                                  48 : Goal(forProjectId: 48, hoursPerMonth: 30, workWeekdays: WeekdaySelection.exceptWeekend) ])

            XCTAssertEqual(idsByGoals.applying(output.moveUpdate), output.projectIDsByGoals)
            XCTAssertEqual(idsByGoals.indexPath(forElementAt: output.moveUpdate.oldIndex), IndexPath(item: 3, section: withoutGoal))
            XCTAssertEqual(output.projectIDsByGoals.indexPath(forElementAt: output.moveUpdate.newIndex), IndexPath(item: 2, section: withGoal))
        } catch {
            XCTFail()
        }
    }
}
