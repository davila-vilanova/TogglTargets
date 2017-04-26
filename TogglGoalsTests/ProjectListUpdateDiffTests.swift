//
//  ProjectListUpdateDiffTests
//  TogglGoals
//
//  Created by David Dávila on 21.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

class ProjectListUpdateDiffTests: XCTestCase {

    func testIndexPathGeneration() {
        let pgs = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                  sortedProjectIds: [4, 1, 5, 9, 2],
                                  indexOfFirstProjectWithoutGoal: 2)
        XCTAssertEqual(pgs.indexPath(for: 0), IndexPath(item: 0, section: 0))
        XCTAssertEqual(pgs.indexPath(for: 1), IndexPath(item: 1, section: 0))
        XCTAssertEqual(pgs.indexPath(for: 2), IndexPath(item: 0, section: 1))
        XCTAssertEqual(pgs.indexPath(for: 3), IndexPath(item: 1, section: 1))
        XCTAssertEqual(pgs.indexPath(for: 4), IndexPath(item: 2, section: 1))
    }

    func testMovedItemsDiff() {
        let oldProjects = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                          sortedProjectIds: [
                                            4, //0 section: 0, item: 0
                                            1, //1 section: 0, item: 1
                                            5, //2 section: 1, item: 0
                                            9, //3 section: 1, item: 1
                                            2],//4 section: 1, item: 2
            indexOfFirstProjectWithoutGoal: 2)
        let newProjects = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                          sortedProjectIds: [
                                            4, //0 section: 0, item: 0
                                            1, //1 section: 0, item: 1
                                            9, //2 section: 0, item: 2
                                            5, //3 section: 1, item: 0
                                            2],//4 section: 1, item: 1
            indexOfFirstProjectWithoutGoal: 3)
        let diff = ProjectListUpdateDiff(oldProjectsValue: oldProjects, newProjectsValue: newProjects)
        XCTAssertEqual(diff.movedItems[IndexPath(item: 0, section: 0)], nil)
        XCTAssertEqual(diff.movedItems[IndexPath(item: 1, section: 0)], nil)
        XCTAssertEqual(diff.movedItems[IndexPath(item: 0, section: 1)], nil)
        XCTAssertEqual(diff.movedItems[IndexPath(item: 1, section: 1)], IndexPath(item: 2, section: 0))
        XCTAssertEqual(diff.movedItems[IndexPath(item: 2, section: 1)], IndexPath(item: 1, section: 1))

        XCTAssertTrue(diff.addedItems.isEmpty)
        XCTAssertTrue(diff.removedItems.isEmpty)
    }

    func testAddedItemsDiff() {
        let oldProjects = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                          sortedProjectIds: [
                                            4, //0 section: 0, item: 0
                                            1, //1 section: 0, item: 1
                                            5, //2 section: 1, item: 0
                                            9, //3 section: 1, item: 1
                                            2],//4 section: 1, item: 2
            indexOfFirstProjectWithoutGoal: 2)
        let newProjects = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                          sortedProjectIds: [
                                            4, //0 section: 0, item: 0
                                            1, //1 section: 0, item: 1
                                            3, //2 section: 0, item: 2
                                            5, //3 section: 1, item: 0
                                            9, //4 section: 1, item: 1
                                            2, //5 section: 1, item: 2
                                            7],//6 section: 1, item: 3
            indexOfFirstProjectWithoutGoal: 3)

        let diff = ProjectListUpdateDiff(oldProjectsValue: oldProjects, newProjectsValue: newProjects)
        XCTAssertTrue(diff.addedItems.contains(IndexPath(item: 2, section: 0)))
        XCTAssertTrue(diff.addedItems.contains(IndexPath(item: 3, section: 1)))
        XCTAssertEqual(diff.addedItems.count, 2)

        XCTAssertTrue(diff.movedItems.isEmpty)
        XCTAssertTrue(diff.removedItems.isEmpty)
    }

    func testRemovedItemsDiff() {
        let oldProjects = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                          sortedProjectIds: [
                                            4, //0 section: 0, item: 0
                                            1, //1 section: 0, item: 1
                                            5, //2 section: 1, item: 0
                                            9, //3 section: 1, item: 1
                                            2],//4 section: 1, item: 2
            indexOfFirstProjectWithoutGoal: 2)
        let newProjects = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                          sortedProjectIds: [
                                            4, //0 section: 0, item: 0
                                            5, //1 section: 1, item: 0
                                            9],//2 section: 1, item: 1
            indexOfFirstProjectWithoutGoal: 1)

        let diff = ProjectListUpdateDiff(oldProjectsValue: oldProjects, newProjectsValue: newProjects)
        XCTAssertTrue(diff.removedItems.contains(IndexPath(item: 1, section: 0)))
        XCTAssertTrue(diff.removedItems.contains(IndexPath(item: 2, section: 1)))
        XCTAssertEqual(diff.removedItems.count, 2)

        XCTAssertTrue(diff.movedItems.isEmpty)
        XCTAssertTrue(diff.addedItems.isEmpty)
    }

    func testMovedAddedRemovedCombinedDifff() {
        let oldProjects = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                          sortedProjectIds: [
                                            4, //0 section: 0, item: 0
                                            1, //1 section: 0, item: 1
                                            5, //2 section: 1, item: 0
                                            9, //3 section: 1, item: 1
                                            2],//4 section: 1, item: 2
            indexOfFirstProjectWithoutGoal: 2)
        let newProjects = ProjectsByGoals(projects: Dictionary<Int64, Project>(),
                                          sortedProjectIds: [
                                            4, //0 section: 0, item: 0
                                            3, //1 section: 0, item: 1
                                            9, //2 section: 0, item: 2
                                            5, //3 section: 1, item: 0
                                            2],//4 section: 1, item: 1
            indexOfFirstProjectWithoutGoal: 3)
        let diff = ProjectListUpdateDiff(oldProjectsValue: oldProjects, newProjectsValue: newProjects)
        XCTAssertEqual(diff.movedItems[IndexPath(item: 0, section: 0)], nil)
        XCTAssertEqual(diff.movedItems[IndexPath(item: 1, section: 0)], nil)
        XCTAssertEqual(diff.movedItems[IndexPath(item: 0, section: 1)], nil)
        XCTAssertEqual(diff.movedItems[IndexPath(item: 1, section: 1)], IndexPath(item: 2, section: 0))
        XCTAssertEqual(diff.movedItems[IndexPath(item: 2, section: 1)], IndexPath(item: 1, section: 1))

        XCTAssertTrue(diff.removedItems.contains(IndexPath(item: 1, section: 0)))
        XCTAssertTrue(diff.addedItems.contains(IndexPath(item: 1, section: 0)))

        XCTAssertEqual(diff.removedItems.count, 1)
        XCTAssertEqual(diff.addedItems.count, 1)
    }
}
