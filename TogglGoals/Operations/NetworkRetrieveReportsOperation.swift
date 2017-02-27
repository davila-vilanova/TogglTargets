//
//  NetworkRetrieveReportsOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

internal class NetworkRetrieveReportsOperation: TogglAPIAccessOperation<Dictionary<Int64, TimeReport>> {
    override var endpointPath: String {
        get {
            let userAgent = "david@davi.la"
            return "\(reportsAPIV2Path)/summary?workspace_id=\(workspaceId)&since=\(formattedSince)&until=\(formattedUntil)&grouping=projects&subgrouping=users&user_agent=\(userAgent)"
        }
    }

    let workspaceId: Int64
    let since: Date
    let formattedSince: String
    let until: Date
    let formattedUntil: String
    let timezone: TimeZone

    init(credential: TogglAPICredential, workspaceId: Int64, since: Date, until: Date, timezone: TimeZone) {
        self.workspaceId = workspaceId
        self.since = since
        self.until = until
        self.timezone = timezone

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        formatter.timeZone = timezone

        formattedSince = formatter.string(from: since)
        formattedUntil = formatter.string(from: until)

        super.init(credential: credential)
    }

    override func unmarshallModel(from data: Data) -> Dictionary<Int64, TimeReport>? {
        var timeReports = Dictionary<Int64, TimeReport>()

        let json = try! JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? Dictionary<String, Any>,
            let projects = dict["data"] as? Array<Dictionary<String, Any>> {
            for p in projects {
                if let id = p["id"] as? NSNumber,
                    let time = p["time"] as? NSNumber {
                    let projectId = id.int64Value
                    let milliseconds = time.doubleValue
                    let timeInterval = milliseconds/1000
                    let report = TimeReport(projectId: projectId, startDate: self.since, endDate: self.until, timezone: timezone,workedTime: timeInterval)
                    timeReports[projectId] = report
                }
            }
        }

        return timeReports
    }
}
