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
