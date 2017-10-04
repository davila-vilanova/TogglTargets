//
//  NetworkRetrieveProfileOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class NetworkRetrieveProfileOperation: TogglAPIAccessOperation<Profile> {
    override var endpointPath: String {
        get {
            return "\(apiV8Path)/me"
        }
    }

    override func unmarshallModel(from data: Data) -> Profile? {
        let json = try! JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? Dictionary<String, Any>,
            let dataDict = dict["data"] as? Dictionary<String, Any>,
            let profile = Profile.fromTogglAPI(dictionary: dataDict) {
            return profile
        } else {
            return nil
        }
    }
}
