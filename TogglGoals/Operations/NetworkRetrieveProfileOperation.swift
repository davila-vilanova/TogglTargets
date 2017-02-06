//
//  NetworkRetrieveProfileOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class NetworkRetrieveProfileOperation: TogglAPIAccessOperation<(Profile, [Workspace], [Project])> {
    override var endpointPath: String {
        get {
            return "/api/v8/me?with_related_data=true"
        }
    }

    override func unmarshallModel(from data: Data) -> (Profile, [Workspace], [Project])? {
        let json = try! JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? Dictionary<String, Any>,
            let dataDict = dict["data"] as? Dictionary<String, Any>,
            let profile = Profile.fromTogglAPI(dictionary: dataDict) {
            let workspaces = Workspace.collectionFromTogglAPI(dictionary: dataDict)
            let projects = Project.collectionFromTogglAPI(dictionary: dataDict)
            return (profile, workspaces, projects)
        }
        return nil
    }
}
