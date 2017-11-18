//
//  TogglAPIAccess.swift
//  TogglGoals
//
//  Created by David Davila on 14/01/2017.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

// TODO: Propagate these type definitions
typealias WorkspaceID = Int64
typealias ProjectID = Int64
typealias IndexedProjects = [ProjectID : Project]
typealias WorkedTime = TimeInterval
typealias IndexedWorkedTimes = [ProjectID : WorkedTime]
typealias IndexedTwoPartTimeReports = [ProjectID : TwoPartTimeReport]


// MARK: APIAccessError

enum APIAccessError: Error {
    case loadingSubsystemError(underlyingError: Error)
    case nonHTTPResponseReceived(response: URLResponse)
    case authenticationError(response: HTTPURLResponse)
    case serverHiccups(response: HTTPURLResponse, data: Data)
    case otherHTTPError(response: HTTPURLResponse)
    case invalidJSON(underlyingError: Error, data: Data)
}


// MARK: - TogglAPIAccess

class TogglAPIAccess {
    let reportPeriodsProducer: ReportPeriodsProducer

    init (reportPeriodsProducer: ReportPeriodsProducer) {
        self.reportPeriodsProducer = reportPeriodsProducer

        latestProfile <~ actionRetrieveProfile.values
        workspaceIDsFromLatestProfile <~ latestProfile.producer.skipNil().map { $0.workspaces.map { $0.id } }
    }


    // MARK: - Exposed inputs

    var apiCredential: BindingTarget<TogglAPICredential> { return _apiCredential.deoptionalizedBindingTarget }


    // MARK: - Backing of inputs

    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)


    // MARK: - Derived properties

    private lazy var urlSession = _apiCredential.producer.skipNil().map(URLSession.init)


    // MARK: - Actions that do most of the actual work

    private let actionRetrieveProfile = Action<URLSession, Profile, APIAccessError> {
        $0.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)
    }

    private let actionRetrieveProjects = Action<(URLSession, [WorkspaceID]), IndexedProjects, APIAccessError> {
        (session, workspaceIDs) in
        let workspaceIDsProducer = SignalProducer(workspaceIDs) // will emit one value per workspace ID
        let projectsProducer: SignalProducer<[Project], APIAccessError> = workspaceIDsProducer
            .map(ProjectsService.endpoint)
            .map { [session] endpoint in
                session.togglAPIRequestProducer(for: endpoint, decoder: ProjectsService.decodeProjects)
            } // will emit one [Project] producer per endpoint, then complete
            .flatten(.concat)

        return projectsProducer.reduce(into: IndexedProjects()) { (indexedProjects, projects) in
            for project in projects {
                indexedProjects[project.id] = project
            }
        }
    }

    private let actionRetrieveReports =
        Action<(URLSession, [WorkspaceID], Period, Period?, Period), IndexedTwoPartTimeReports, APIAccessError> {
            (session, workspaceIDs, fullPeriod, periodUntilYesterday, todayPeriod) in

            let workedUntilYesterday = workedTimesProducer(session: session, workspaceIDs: workspaceIDs, period: periodUntilYesterday)
            let workedToday = workedTimesProducer(session: session, workspaceIDs: workspaceIDs, period: todayPeriod)
            return SignalProducer.combineLatest(workedUntilYesterday, workedToday, SignalProducer(value: fullPeriod))
                .map(generateIndexedReportsFromWorkedTimes)
    }

    private let actionRetrieveRunningEntry = Action<URLSession, RunningEntry?, APIAccessError> {
        $0.togglAPIRequestProducer(for: RunningEntryService.endpoint, decoder: RunningEntryService.decodeRunningEntry)
    }

    // MARK: Intermediate properties
    /// Populated by some action's outputs, these properties hold data from which other actions will take in their input

    private let latestProfile = MutableProperty<Profile?>(nil)
    private let workspaceIDsFromLatestProfile = MutableProperty<[WorkspaceID]?>(nil)


    // MARK: - Output interface for consumer

    func makeProfileProducer() -> SignalProducer<SignalProducer<Profile, APIAccessError>, NoError> {
        return urlSession.map { [actionRetrieveProfile] in
            actionRetrieveProfile.apply($0).mapError(assertProducerError)
        }
    }

    func makeProjectsProducer() -> SignalProducer<SignalProducer<IndexedProjects, APIAccessError>, NoError> {
        return urlSession.combineLatest(with: workspaceIDsFromLatestProfile.producer.skipNil())
            .map { [actionRetrieveProjects] in
                actionRetrieveProjects.apply($0).mapError(assertProducerError)
        }
    }

    func makeReportsProducer() -> SignalProducer<SignalProducer<IndexedTwoPartTimeReports, APIAccessError>, NoError> {
        return SignalProducer.combineLatest(urlSession,
                                            workspaceIDsFromLatestProfile.producer.skipNil(),
                                            reportPeriodsProducer.fullPeriod,
                                            reportPeriodsProducer.previousToTodayPeriod,
                                            reportPeriodsProducer.todayPeriod)
            .map { [actionRetrieveReports] in
                actionRetrieveReports.apply($0).mapError(assertProducerError)
        }
    }

    func makeRunningEntryProducer() -> SignalProducer<SignalProducer<RunningEntry?, APIAccessError>, NoError> {
        return urlSession.map { [actionRetrieveRunningEntry] in
            actionRetrieveRunningEntry.apply($0).mapError(assertProducerError)
        }
    }
}

// MARK: - Helpers to TogglAPIAccess that don't depend on its (hopefully minimal) state

/// Returns a producer that, on success, emits a single IndexedWorkedTimes value
/// corresponding to the aggregate of all the provided workspace IDs, then completes.
fileprivate func workedTimesProducer(session: URLSession, workspaceIDs: [WorkspaceID], period: Period?)
    -> SignalProducer<IndexedWorkedTimes, APIAccessError> {
        guard session.canAccessTogglReportsAPI else {
            assert(false, "Session is not suitable for accessing the Toggl API") // TODO: codify in type?
            return SignalProducer(value: IndexedWorkedTimes()) // empty
        }
        guard let period = period else {
            return SignalProducer(value: IndexedWorkedTimes()) // empty
        }

        func timesProducer(forSingle workspaceID: WorkspaceID) -> SignalProducer<IndexedWorkedTimes, APIAccessError> {
            let endpoint =
                ReportsService.endpoint(workspaceId: workspaceID,
                                        since: period.start.iso8601String, until: period.end.iso8601String,
                                        userAgent: UserAgent)
            return session.togglAPIRequestProducer(for: endpoint, decoder: ReportsService.decodeReportEntries)
                .reduce(into: IndexedWorkedTimes()) { (indexedWorkedTimeEntries, reportEntries) in
                    for entry in reportEntries {
                        indexedWorkedTimeEntries[entry.id] = WorkedTime.from(milliseconds: entry.time)
                    }
            }
        }

        return SignalProducer(workspaceIDs)
            .map(timesProducer)
            .flatten(.concat)
            .reduce(IndexedWorkedTimes(), { (combined: IndexedWorkedTimes, thisWorkspace: IndexedWorkedTimes) -> IndexedWorkedTimes in
                combined.merging(thisWorkspace, uniquingKeysWith: { valueInCombinedTimes, _ in valueInCombinedTimes }) // Not expecting duplicates
            })
}

fileprivate func generateIndexedReportsFromWorkedTimes(untilYesterday: IndexedWorkedTimes,
                                                       today: IndexedWorkedTimes,
                                                       fullPeriod: Period)
    -> [Int64 : TwoPartTimeReport] {
        var reports = [Int64 : TwoPartTimeReport]()
        let ids: Set<Int64> = Set<Int64>(untilYesterday.keys).union(today.keys)
        for id in ids {
            let timeWorkedPreviousToToday: TimeInterval = untilYesterday[id] ?? 0.0
            let timeWorkedToday: TimeInterval = today[id] ?? 0.0
            reports[id] = TwoPartTimeReport(projectId: id,
                                            since: fullPeriod.start,
                                            until: fullPeriod.end,
                                            workedTimeUntilYesterday: timeWorkedPreviousToToday,
                                            workedTimeToday: timeWorkedToday)
        }
        return reports
}

// TODO: Reassess if any of the actions above can be attempted to run while not available
// TODO: find a clearer name for this function if it's to be kept around
fileprivate func assertProducerError(actionError: ActionError<APIAccessError>) -> APIAccessError {
    switch actionError {
    case .disabled:
        print("unexpected ActionError.disabled: \(actionError)")
        return .loadingSubsystemError(underlyingError: NSError(domain: "this should be a fatal error", code: -1, userInfo: nil))
    case .producerFailed(let apiAccessError):
        return apiAccessError
    }
}





// MARK: - URLSession

extension URLSession {
    convenience init(togglAPICredential: TogglAPICredential) {
        let authHeaders: [String: String] = [ togglAPICredential.authHeaderKey : togglAPICredential.authHeaderValue ]
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = authHeaders
        self.init(configuration: config)
    }

    var canAccessTogglReportsAPI: Bool {
        guard let headers = configuration.httpAdditionalHeaders else {
            return false
        }
        return TogglAPITokenCredential.headersIncludeTokenAuthenticationEntry(headers)
    }

    func togglAPIRequestProducer(for endpoint: String) -> SignalProducer<(Data, URLResponse), APIAccessError> {
        func resourceURL(for endpoint: String) -> URL {
            let rootAPIURLString = "https://www.toggl.com"
            let resourceURLString = rootAPIURLString + endpoint
            return URL(string: resourceURLString)!
        }

        func request(for path: String) -> URLRequest {
            return URLRequest(url: resourceURL(for: path))
        }

        print("** sending request to \(endpoint) **")
        return APIAccessError.mapErrors(from: self.reactive.data(with: request(for: endpoint)))
    }

    func togglAPIRequestProducer<U>(for endpoint: String, decoder: @escaping ((Data, URLResponse) throws -> U)) -> SignalProducer<U, APIAccessError> {
        return togglAPIRequestProducer(for: endpoint)
            .attemptMap({ (data, response) -> Result<U, APIAccessError> in
                do {
                    return .success(try decoder(data, response))
                } catch {
                    return .failure(APIAccessError.invalidJSON(underlyingError: error, data: data))
                }
            })
    }

    static func requestDataToString(data: Data, response: URLResponse) -> String {
        return String(data: data, encoding: .utf8)!
    }
}

// MARK: - Handy additions to APIAccessError

fileprivate extension APIAccessError {
    static func wrapAnyErrorInLoadingSubsystemError(_ err: AnyError) -> APIAccessError {
        return APIAccessError.loadingSubsystemError(underlyingError: err)
    }

    static func catchHTTPErrors(data: Data, response: URLResponse) -> Result<(Data, URLResponse), APIAccessError> {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(APIAccessError.nonHTTPResponseReceived(response: response))
        }
        switch (httpResponse.statusCode) {
        case 200...299, 100...199, 300...399: break
        case 403: return .failure(APIAccessError.authenticationError(response: httpResponse))
        case 500...599: return .failure(APIAccessError.serverHiccups(response: httpResponse, data: data))
        case 400...499: return .failure(APIAccessError.otherHTTPError(response: httpResponse))
        default: return .failure(APIAccessError.otherHTTPError(response: httpResponse))
        }
        return .success((data, httpResponse))
    }

    static func mapErrors(from producer: SignalProducer<(Data, URLResponse), AnyError>) -> SignalProducer<(Data, URLResponse), APIAccessError> {
        return producer.mapError(wrapAnyErrorInLoadingSubsystemError)
            .attemptMap(catchHTTPErrors)
    }
}

// MARK: - User agent
fileprivate let UserAgent = "david@davi.la"

// MARK: - Service definitions

struct MeService: Decodable {
    static let endpoint = "/api/v8/me"
    let profile: Profile

    private enum CodingKeys: String, CodingKey {
        case profile = "data"
    }

    static func decodeProfile(data: Data, response: URLResponse) throws -> Profile {
        return try JSONDecoder().decode(MeService.self, from: data).profile
    }
}

struct ProjectsService {
    static func endpoint(for workspaceId: Int64) -> String {
        return "/api/v8/workspaces/\(workspaceId)/projects"
    }

    static func decodeProjects(data: Data, response: URLResponse) throws -> [Project] {
        return try JSONDecoder().decode([Project].self, from: data)
    }
}

struct ReportsService: Decodable {
    static func endpoint(workspaceId: Int64, since: String, until: String, userAgent: String) -> String {
        return "/reports/api/v2/summary?workspace_id=\(workspaceId)&since=\(since)&until=\(until)&grouping=projects&subgrouping=users&user_agent=\(userAgent)"
    }

    let reportEntries: [ReportEntry]
    struct ReportEntry: Decodable {
        let id: Int64
        let time: TimeInterval
    }

    private enum CodingKeys: String, CodingKey {
        case reportEntries = "data"
    }

    static func decodeReportEntries(data: Data, response: URLResponse) throws -> [ReportsService.ReportEntry] {
        return try JSONDecoder().decode(ReportsService.self, from: data).reportEntries
    }
}

extension ReportsService {
    static func endpoint(with userAgent: String) -> (Int64, DayComponents, DayComponents) -> String {
        return { (workspaceId, since, until) in
            ReportsService.endpoint(workspaceId: workspaceId, since: since.iso8601String, until: until.iso8601String, userAgent: userAgent)
        }
    }

}

struct RunningEntryService: Decodable {
    static let endpoint = "/api/v8/time_entries/current"

    let runningEntry: RunningEntry?

    private enum CodingKeys: String, CodingKey {
        case runningEntry = "data"
    }

    static func decodeRunningEntry(data: Data, response: URLResponse) throws -> RunningEntry? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RunningEntryService.self, from: data).runningEntry
    }
}



