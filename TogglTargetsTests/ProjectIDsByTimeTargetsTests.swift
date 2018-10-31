//
//  ProjectIDsByTimeTargetsTests.swift
//  TogglTargetsTests
//
//  Created by David Dávila on 07.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

fileprivate let withTimeTargets = ProjectIDsByTimeTargets.Section.withTimeTargets.rawValue
fileprivate let withoutTimeTargets = ProjectIDsByTimeTargets.Section.withoutTimeTargets.rawValue

class ProjectIDsByTimeTargetsTests: XCTestCase {

    let idsByTimeTargets = ProjectIDsByTimeTargets(sortedProjectIDs: [897, 1243, 6103, 321407, 23, 0, 1432075, 12, 400],
                                                   countOfProjectsWithTimeTargets: 4)

    func testCountOfProjectsWithoutTimeTargets() {
        XCTAssertEqual(idsByTimeTargets.countOfProjectsWithoutTimeTargets, 5)
    }

    func testEquality() {
        let a = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithTimeTargets: 2)
        let b = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithTimeTargets: 2)
        XCTAssertTrue(a == b)
        XCTAssertFalse(a != b)
    }

    func testNonEqualityByDifferingOrder() {
        let a = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithTimeTargets: 2)
        let b = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 2], countOfProjectsWithTimeTargets: 2)
        XCTAssertTrue(a != b)
        XCTAssertFalse(a == b)
    }

    func testNonEqualityByDifferingCount() {
        let a = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithTimeTargets: 2)
        let b = ProjectIDsByTimeTargets(sortedProjectIDs: [1, 2, 3], countOfProjectsWithTimeTargets: 1)
        XCTAssertTrue(a != b)
        XCTAssertFalse(a == b)
    }

    func testIndexPathGeneration() {
        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: 0), IndexPath(item: 0, section: withTimeTargets))
        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: 1), IndexPath(item: 1, section: withTimeTargets))
        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: 3), IndexPath(item: 3, section: withTimeTargets))
        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: 4), IndexPath(item: 0, section: withoutTimeTargets))
        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: 5), IndexPath(item: 1, section: withoutTimeTargets))
        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: 8), IndexPath(item: 4, section: withoutTimeTargets))
    }

    func testIndexPathInterpretation() {
        XCTAssertEqual(idsByTimeTargets.projectId(for: IndexPath(item: 1, section: withTimeTargets)), 1243)
        XCTAssertEqual(idsByTimeTargets.projectId(for: IndexPath(item: 2, section: withoutTimeTargets)), 1432075)
    }
}

fileprivate let SetupFailure = "Test setup failure: "
fileprivate let SetupFailureNilIndexedTimeTargets = "\(SetupFailure)indexedTimeTargets and projectId must not be nil"
fileprivate let SetupFailureNonMatchingProjectId = "\(SetupFailure)if a newTimeTarget is provided, newTimeTarget's projectId must match provided projectId"
fileprivate let SetupFailureNilIdsByTimeTargets = "\(SetupFailure)idsByTimeTargets must not be nil"
fileprivate let SetupFailureNilProjectId = "\(SetupFailure)after calling setupForProjectId(_, newTimeTarget:) projectId must not be nil"

class ProjectIDsByTimeTargetsUpdateTests: XCTestCase {
    var indexedTimeTargets: ProjectIdIndexedTimeTargets?
    var projectIDs: [ProjectID]?
    var idsByTimeTargets: ProjectIDsByTimeTargets?

    var projectId: ProjectID?
    var oldTimeTarget: TimeTarget?
    var newTimeTarget: TimeTarget?
    var newIndexedTimeTargets: ProjectIdIndexedTimeTargets?

    typealias TimeTargetUpdate = ProjectIDsByTimeTargets.Update.TimeTargetUpdate

    // Updates the values of projectId, oldTimeTarget, newTimeTarget and newIndexedTimeTargets
    func setUpForProjectId(_ projectId: ProjectID, newTimeTarget: TimeTarget?) {
        guard let oldIndexedTimeTargets = indexedTimeTargets else {
            XCTFail(SetupFailureNilIndexedTimeTargets)
            return
        }
        guard newTimeTarget == nil || newTimeTarget!.projectId == projectId else {
            XCTFail(SetupFailureNonMatchingProjectId)
            return
        }

        self.projectId = projectId
        self.newTimeTarget = newTimeTarget
        oldTimeTarget = oldIndexedTimeTargets[projectId]
        newIndexedTimeTargets = {
            var t = oldIndexedTimeTargets
            t[projectId] = newTimeTarget
            return t
        }()
    }

    override func setUp() {
        super.setUp()
        indexedTimeTargets = [ 71 : TimeTarget(for: 71, hoursTarget: 10, workWeekdays: WeekdaySelection.exceptWeekend),
                         25 : TimeTarget(for: 25, hoursTarget: 20, workWeekdays: WeekdaySelection.wholeWeek),
                         90 : TimeTarget(for: 90, hoursTarget: 50, workWeekdays: WeekdaySelection.exceptWeekend),
                         48 : TimeTarget(for: 48, hoursTarget: 30, workWeekdays: WeekdaySelection.exceptWeekend) ]
        projectIDs = [30, 12, 25, 89, 22, 48, 71, 60]

        idsByTimeTargets = ProjectIDsByTimeTargets(projectIDs: projectIDs!, timeTargets: indexedTimeTargets!)

        projectId = nil
        oldTimeTarget = nil
        newTimeTarget = nil
        newIndexedTimeTargets = nil
    }

    func testInitialization() {
        guard let idsByTimeTargets = idsByTimeTargets else {
            XCTFail(SetupFailureNilIdsByTimeTargets)
            return
        }
        XCTAssertEqual(idsByTimeTargets.sortedProjectIDs, [48, 25, 71, 89, 60, 30, 22, 12])
        XCTAssertEqual(idsByTimeTargets.countOfProjectsWithTimeTargets, 3)
    }

    func testEditExistingTimeTarget() {
        guard let idsByTimeTargets = idsByTimeTargets else {
            XCTFail(SetupFailureNilIdsByTimeTargets)
            return
        }
        guard let indexedTimeTargets = indexedTimeTargets else {
            XCTFail(SetupFailureNilIndexedTimeTargets)
            return
        }

        setUpForProjectId(48, newTimeTarget: TimeTarget(for: 48, hoursTarget: 15, workWeekdays: WeekdaySelection.exceptWeekend))
        guard let projectId = projectId else {
            XCTFail(SetupFailureNilProjectId)
            return
        }

        let timeTargetUpdate = TimeTargetUpdate.forTimeTargetChange(involving: newTimeTarget,
                                                                    for: projectId,
                                                                    within: indexedTimeTargets,
                                                                    affecting: idsByTimeTargets)
        guard let update = timeTargetUpdate else {
            XCTFail()
            return
        }

        let indexChange = update.indexChange
        XCTAssertEqual(indexChange.old, 0)
        XCTAssertEqual(indexChange.new, 1)
        XCTAssertEqual(update.computeNewCount(from: idsByTimeTargets), 3)

        let newIdsByTimeTargets = update.apply(to: idsByTimeTargets)
        XCTAssertEqual(newIdsByTimeTargets.sortedProjectIDs, [25, 48, 71, 89, 60, 30, 22, 12])
        XCTAssertEqual(newIdsByTimeTargets.countOfProjectsWithTimeTargets, 3)

        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: indexChange.old), IndexPath(item: 0, section: withTimeTargets))
        XCTAssertEqual(newIdsByTimeTargets.indexPath(forElementAt: indexChange.new), IndexPath(item: 1, section: withTimeTargets))
    }


    func testDeleteTimeTarget() {
        guard let idsByTimeTargets = idsByTimeTargets else {
            XCTFail(SetupFailureNilIdsByTimeTargets)
            return
        }
        guard let indexedTimeTargets = indexedTimeTargets else {
            XCTFail(SetupFailureNilIndexedTimeTargets)
            return
        }

        setUpForProjectId(25, newTimeTarget: nil)
        guard let projectId = projectId else {
            XCTFail(SetupFailureNilProjectId)
            return
        }

        let timeTargetUpdate = TimeTargetUpdate.forTimeTargetChange(involving: newTimeTarget,
                                                                    for: projectId,
                                                                    within: indexedTimeTargets,
                                                                    affecting: idsByTimeTargets)
        guard let update = timeTargetUpdate else {
            XCTFail()
            return
        }

        let indexChange = update.indexChange
        XCTAssertEqual(indexChange.old, 1)
        XCTAssertEqual(indexChange.new, 5)
        XCTAssertEqual(update.computeNewCount(from: idsByTimeTargets), 2)

        let newIdsByTimeTargets = update.apply(to: idsByTimeTargets)
        XCTAssertEqual(newIdsByTimeTargets.sortedProjectIDs, [48, 71, 89, 60, 30, 25, 22, 12])
        XCTAssertEqual(newIdsByTimeTargets.countOfProjectsWithTimeTargets, 2)

        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: indexChange.old), IndexPath(item: 1, section: withTimeTargets))
        XCTAssertEqual(newIdsByTimeTargets.indexPath(forElementAt: indexChange.new), IndexPath(item: 3, section: withoutTimeTargets))
    }

    func testCreateTimeTarget() {
        guard let idsByTimeTargets = idsByTimeTargets else {
            XCTFail(SetupFailureNilIdsByTimeTargets)
            return
        }
        guard let indexedTimeTargets = indexedTimeTargets else {
            XCTFail(SetupFailureNilIndexedTimeTargets)
            return
        }

        setUpForProjectId(22, newTimeTarget: TimeTarget(for: 22, hoursTarget: 16, workWeekdays: WeekdaySelection.exceptWeekend))
        guard let projectId = projectId else {
            XCTFail(SetupFailureNilProjectId)
            return
        }

        let timeTargetUpdate = TimeTargetUpdate.forTimeTargetChange(involving: newTimeTarget,
                                                                    for: projectId,
                                                                    within: indexedTimeTargets,
                                                                    affecting: idsByTimeTargets)

        guard let update = timeTargetUpdate else {
            XCTFail()
            return
        }

        let indexChange = update.indexChange
        XCTAssertEqual(indexChange.old, 6)
        XCTAssertEqual(indexChange.new, 2)
        XCTAssertEqual(update.computeNewCount(from: idsByTimeTargets), 4)

        let newIdsByTimeTargets = update.apply(to: idsByTimeTargets)
        XCTAssertEqual(newIdsByTimeTargets.sortedProjectIDs, [48, 25, 22, 71, 89, 60, 30, 12])
        XCTAssertEqual(newIdsByTimeTargets.countOfProjectsWithTimeTargets, 4)

        XCTAssertEqual(idsByTimeTargets.indexPath(forElementAt: indexChange.old), IndexPath(item: 3, section: withoutTimeTargets))
        XCTAssertEqual(newIdsByTimeTargets.indexPath(forElementAt: indexChange.new), IndexPath(item: 2, section: withTimeTargets))
    }
}
