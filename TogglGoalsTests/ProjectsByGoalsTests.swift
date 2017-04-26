//
//  ProjectsByGoalsTests.swift
//  TogglGoals
//
//  Created by David Dávila on 24.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import XCTest

class ProjectsByGoalsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        let pbgs = ProjectsByGoals(projects: Dictionary<Int64, Project>(), sortedProjectIds: [45, 4, 31, 5], indexOfFirstProjectWithoutGoal: 2)
        XCTAssertEqual(pbgs.idsOfProjectsWithGoals, [45, 4])
        XCTAssertEqual(pbgs.idsOfProjectsWithoutGoals, [31, 5])
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
