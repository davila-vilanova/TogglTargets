//
//  NetworkRetrieveProjectsOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class NetworkRetrieveProjectsOperation: TogglAPIAccessOperation<[Project]> {
    internal let workspaceId: Int64

    init(credential: TogglAPICredential, workspaceId: Int64) {
        self.workspaceId = workspaceId
        super.init(credential: credential)
    }

    override var endpointPath: String {
        get {
            return "\(apiV8Path)/workspaces/\(workspaceId)/projects"
        }
    }

    override func unmarshallModel(from data: Data) -> [Project]? {
        let json = try! JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? [Dictionary<String, Any>] {
            let projects = Project.collectionFromTogglAPI(dictionaries: dict)
            return projects
        } else {
            return nil
        }
    }
}

/** 
  Spawns NetworkRetrieveProjectsOperations from the results of a NetworkRetrieveWorkspacesOperation
  Collects all retrieved projects in an array of Projects
*/
class NetworkRetrieveProjectsSpawningOperation: SpawningOperation<Workspace, [Project], NetworkRetrieveProjectsOperation> {
  
    typealias CollectedOutput = [Project]
    
    init(retrieveWorkspacesOperation: NetworkRetrieveWorkspacesOperation,
         credential: TogglAPICredential,
         onComplete: @escaping (CollectedOutput) -> ()) {
        
        func makeSpawnedOperations(from workspace: Workspace) -> [TogglAPIAccessOperation<[Project]>] {
            return [NetworkRetrieveProjectsOperation(credential: credential, workspaceId: workspace.id)]
        }
     
        func collectProjectsRetrieved(by allSpawnedOperations: Set<NetworkRetrieveProjectsOperation>) -> CollectedOutput {
            var allProjects = [Project]()
            for retrieveProjectsOperation in allSpawnedOperations {
                if let retrievedProjects = retrieveProjectsOperation.model {
                    allProjects.append(contentsOf: retrievedProjects)
                }
            }
            return allProjects
        }

        super.init(inputRetrievalOperation: retrieveWorkspacesOperation,
                   spawnedOperationsMaker: makeSpawnedOperations) { spawnedRetrieveProjectsOperations in
                    onComplete(collectProjectsRetrieved(by: spawnedRetrieveProjectsOperations))
        }
    }
}
