//
//  NetworkRetrieveWorkspacesOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class NetworkRetrieveWorkspacesOperation: TogglAPIAccessOperation<[Workspace]> {
    override var endpointPath: String {
        get {
            return "\(apiV8Path)/workspaces"
        }
    }

    override func unmarshallModel(from data: Data) -> [Workspace]? {
        let json = try! JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? [Dictionary<String, Any>] {
            let workspaces = Workspace.collectionFromTogglAPI(dictionaries: dict)
            return workspaces
        } else {
            return nil
        }
    }
}
