//
//  NetworkRetrieveRunningEntryOperation.swift
//  TogglGoals
//
//  Created by David Davila on 18.03.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation


class NetworkRetrieveRunningEntryOperation: TogglAPIAccessOperation<RunningEntry> {
    override var endpointPath: String {
        return "\(apiV8Path)/time_entries/current"
    }

    override func unmarshallModel(from data: Data) -> RunningEntry? {
        let json = try! JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? Dictionary<String, Any>,
            let dataDict = dict["data"] as? Dictionary<String, Any>,
            let runningEntry = RunningEntry.fromTogglAPI(dictionary: dataDict) {
            return runningEntry
        } else {
            return nil
        }
    }
}

extension RunningEntry {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> RunningEntry? {
        if let id = dictionary["id"] as? Int64,
            let projectId = dictionary["projectId"] as? Int64,
            let start = dictionary["start"] as? String,
            let parsedStart = ISO8601DateFormatter().date(from: start) {
            return RunningEntry(id: id, projectId: projectId, start: parsedStart)
        } else {
            return nil
        }
    }
}
