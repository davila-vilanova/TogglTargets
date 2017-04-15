//
//  ProjectsGoalsReportsCollectingOperation.swift
//  TogglGoals
//
//  Created by David Dávila on 14.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class ProjectsGoalsReportsCollectingOperation: Operation {
    typealias Output = [Troika]
    
    let retrieveProjectsOperation: NetworkRetrieveProjectsSpawningOperation
    let retrieveReportsOperation: NetworkRetrieveReportsSpawningOperation
    let goalStore: GoalsStore
    let onComplete: (Output) -> ()
    
    init(retrieveProjectsOperation: NetworkRetrieveProjectsSpawningOperation,
         retrieveReportsOperation: NetworkRetrieveReportsSpawningOperation,
         goalStore: GoalsStore,
         onComplete: @escaping (Output) -> ()) {
        
        self.retrieveProjectsOperation = retrieveProjectsOperation
        self.retrieveReportsOperation = retrieveReportsOperation
        self.goalStore = goalStore
        self.onComplete = onComplete
        
        super.init()
        
        addDependency(retrieveProjectsOperation.outputCollectionOperation)
        addDependency(retrieveReportsOperation.outputCollectionOperation)
    }
    
    override func main() {
        guard !isCancelled else {
            return
        }
        
        guard let projects = retrieveProjectsOperation.collectedOutput else {
            return
        }
        
        let reports = retrieveReportsOperation.collectedOutput
        var output = Output()
        
        for project in projects {
            let projectId = project.id
            let goal = goalStore.retrieveGoal(projectId: projectId)
            let report = reports?[projectId]
            output.append(Troika(project: project, goal: goal, report: report))
        }
        
        DispatchQueue.main.async {
            self.onComplete(output)
        }
    }
}
