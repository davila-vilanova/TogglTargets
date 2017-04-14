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
    let since: DayComponents
    let formattedSince: String
    let until: DayComponents
    let formattedUntil: String

    init(credential: TogglAPICredential, workspaceId: Int64, since: DayComponents, until: DayComponents) {
        self.workspaceId = workspaceId
        self.since = since
        self.until = until

        formattedSince = ISO8601Date(from: since)
        formattedUntil = ISO8601Date(from: until)

        super.init(credential: credential)
    }

    convenience init(credential: TogglAPICredential, workspaceId: Int64, singleDay: DayComponents) {
        self.init(credential: credential, workspaceId: workspaceId, since: singleDay, until: singleDay)
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
                    let report = SingleTimeReport(projectId: projectId, since: self.since, until: self.until, workedTime: timeInterval)
                    timeReports[projectId] = report
                }
            }
        }

        return timeReports
    }
}

fileprivate func ISO8601Date(from comps: DayComponents) -> String{
    return String(format:"%04d-%02d-%02d", comps.year, comps.month, comps.day)
}

/**
 Spawns NetworkRetrieveReportsOperations from the results of a NetworkRetrieveWorkspacesOperation
 Collects all retrieved reports in a Dictionary<Int64, TwoPartTimeReport>
*/
internal class NetworkRetrieveReportsSpawningOperation: SpawningOperation<Workspace, Dictionary<Int64, TimeReport>,  NetworkRetrieveReportsOperation> {
    
    typealias CollectedOutput = Dictionary<Int64, TwoPartTimeReport>
    
    init(retrieveWorkspacesOperation: NetworkRetrieveWorkspacesOperation,
         credential: TogglAPICredential,
         calendar: Calendar,
         onComplete: @escaping (CollectedOutput) -> ()) {
        
        let now = Date()
        let startOfPeriod = calendar.firstDayOfMonth(for: now)
        let yesterday = try? calendar.previousDay(for: now, notBefore: startOfPeriod)
        let today = calendar.dayComponents(from: now)

        func makeSpawnedOperations(from workspace: Workspace) -> [TogglAPIAccessOperation<Dictionary<Int64, TimeReport>>] {
            let retrieveUpToYesterdayReportOperation: NetworkRetrieveReportsOperation?
            if let y = yesterday {
                retrieveUpToYesterdayReportOperation =
                    NetworkRetrieveReportsOperation(credential: credential, workspaceId: workspace.id,
                                                    since: startOfPeriod, until: y)
            } else {
                retrieveUpToYesterdayReportOperation = nil
            }
            let retrieveTodayReport =
                NetworkRetrieveReportsOperation(credential: credential, workspaceId: workspace.id, singleDay: today)
            if let r = retrieveUpToYesterdayReportOperation {
                return [r, retrieveTodayReport]
            } else {
                return [retrieveTodayReport]
            }
        }
        
        func collectReportsRetrieved(by allSpawnedOperations: Set<NetworkRetrieveReportsOperation>) -> CollectedOutput {
            var upToYesterdayReports = Dictionary<Int64, TimeReport>()
            var todayReports = Dictionary<Int64, TimeReport>()
            var collectedReports = CollectedOutput()
            
            func addReportToCollected(for projectId: Int64, workedTimeUntilYesterday: TimeInterval, workedTimeToday: TimeInterval) {
                collectedReports[projectId] =
                    TwoPartTimeReport(projectId: projectId, since: startOfPeriod, until: today,
                                      workedTimeUntilYesterday: workedTimeUntilYesterday,
                                      workedTimeToday: workedTimeToday)
            }
            
            for retrieveReportsOperation in allSpawnedOperations {
                guard let retrievedReports = retrieveReportsOperation.model else {
                    continue
                }
                for (projectId, report) in retrievedReports {
                    switch report.since {
                    case startOfPeriod: upToYesterdayReports[projectId] = report
                    case today: todayReports[projectId] = report
                    default: assert (false, "report has unexpected start date")
                    }
                }
                
                for (projectId, upToYesterdayReport) in upToYesterdayReports {
                    let workedTimeUntilYesterday = upToYesterdayReport.workedTime
                    let workedTimeToday: TimeInterval
                    
                    if let todayReport = todayReports[projectId] {
                        workedTimeToday = todayReport.workedTime
                        todayReports.removeValue(forKey: projectId)
                    } else {
                        workedTimeToday = 0
                    }
                    
                    addReportToCollected(for: projectId, workedTimeUntilYesterday: workedTimeUntilYesterday, workedTimeToday: workedTimeToday)
                }
                
                for (projectId, todayReport) in todayReports {
                    let workedTimeToday = todayReport.workedTime
                    let workedTimeUntilYesterday: TimeInterval
                    
                    if let upToYesterdayReport = upToYesterdayReports[projectId] {
                        workedTimeUntilYesterday = upToYesterdayReport.workedTime
                    } else {
                        workedTimeUntilYesterday = 0
                    }
                    
                    addReportToCollected(for: projectId, workedTimeUntilYesterday: workedTimeUntilYesterday, workedTimeToday: workedTimeToday)
                }
            }
            
            return collectedReports
        }
        
        super.init(inputRetrievalOperation: retrieveWorkspacesOperation,
                   spawnedOperationsMaker: makeSpawnedOperations) { spawnedRetrieveReportsOperations in
                    onComplete(collectReportsRetrieved(by: spawnedRetrieveReportsOperations))
        }
    }
}
