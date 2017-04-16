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

    let credential: TogglAPICredential
    
    init(retrieveWorkspacesOperation: NetworkRetrieveWorkspacesOperation, credential: TogglAPICredential) {
        self.credential = credential
        super.init(inputRetrievalOperation: retrieveWorkspacesOperation)
        super.outputCollectionOperation.collectionClosure = { spawnedOperations in
        }
    }
    
    override func makeOperationsToSpawn(from workspace: Workspace) -> [NetworkRetrieveProjectsOperation] {
        return [NetworkRetrieveProjectsOperation(credential: credential, workspaceId: workspace.id)]
    }
}

class ProjectsCollectionOperation: CollectionOperation<NetworkRetrieveProjectsOperation, Dictionary<Int64, Project>> {
    func collectOutput(_ collectableOperations: Set<NetworkRetrieveProjectsOperation>) -> Dictionary<Int64, Project>? {
        var allProjects = [Project]()
        for retrieveProjectsOperation in collectableOperations {
            if let retrievedProjects = retrieveProjectsOperation.model {
                for project in retrievePro
                
                allProjects.append(contentsOf: retrievedProjects)
            }
        }
        return allProjects
    }
}
