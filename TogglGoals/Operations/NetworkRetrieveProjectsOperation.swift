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

    var collectedOutput: CollectedOutput?
    
    let credential: TogglAPICredential
    
    init(retrieveWorkspacesOperation: NetworkRetrieveWorkspacesOperation, credential: TogglAPICredential) {
        self.credential = credential
        super.init(inputRetrievalOperation: retrieveWorkspacesOperation)
    }
    
    override func makeOperationsToSpawn(from workspace: Workspace) -> [NetworkRetrieveProjectsOperation] {
        return [NetworkRetrieveProjectsOperation(credential: credential, workspaceId: workspace.id)]
    }
    
    override func collectOutput(from spawnedOperations: Set<NetworkRetrieveProjectsOperation>) {
        var allProjects = [Project]()
        for retrieveProjectsOperation in spawnedOperations {
            if let retrievedProjects = retrieveProjectsOperation.model {
                allProjects.append(contentsOf: retrievedProjects)
            }
        }
        collectedOutput = allProjects
    }
}
