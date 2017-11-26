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

    // MARK: - Exposed inputs

    internal var apiCredential: BindingTarget<TogglAPICredential?> { return _apiCredential.bindingTarget }
    internal var twoPartTimeReportPeriods: BindingTarget<TwoPartTimeReportPeriods> { return _twoPartTimeReportPeriods.deoptionalizedBindingTarget }

    // MARK: - Backing of inputs

    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)
    private let _twoPartTimeReportPeriods = MutableProperty<TwoPartTimeReportPeriods?>(nil)

    // MARK: - Intermediary properties

    private lazy var urlSession: Property<URLSession?> = {
        let m = MutableProperty<URLSession?>(nil)
        m <~ _apiCredential.producer.skipNil().map(URLSession.init)
        return Property(capturing: m)
    }()

    private lazy var workspaceIDs: Property<[WorkspaceID]?> = {
        let m = MutableProperty<[WorkspaceID]?>(nil)
        m <~ actionRetrieveProfile.values.map { $0.workspaces.map { $0.id } }
        return Property(capturing: m)
    }()

    private lazy var retrieveProjectsInput: Property<(URLSession, [WorkspaceID])?> = {
        let m = MutableProperty<(URLSession, [WorkspaceID])?>(nil)
        m <~ SignalProducer.combineLatest(urlSession, workspaceIDs).map {
            urlSessionOrNil, workspaceIDsOrNil -> (URLSession, [WorkspaceID])? in
            if let urlSession = urlSessionOrNil,
                let workspaceIDs = workspaceIDsOrNil {
                return (urlSession, workspaceIDs)
            } else {
                return nil
            }
        }
        return Property(capturing: m)
    }()

    private lazy var retrieveReportsInput: Property<(URLSession, [WorkspaceID], TwoPartTimeReportPeriods)?> = {
        let m = MutableProperty<(URLSession, [WorkspaceID], TwoPartTimeReportPeriods)?>(nil)
        m <~ SignalProducer.combineLatest(urlSession, workspaceIDs, _twoPartTimeReportPeriods).map {
            urlSessionOrNil, workspaceIDsOrNil, twoPartTimeReportPeriodsOrNil -> (URLSession, [WorkspaceID], TwoPartTimeReportPeriods)? in
            if let urlSession = urlSessionOrNil,
                let workspaceIDs = workspaceIDsOrNil,
                let twoPartTimeReportPeriods = twoPartTimeReportPeriodsOrNil {
                return (urlSession, workspaceIDs, twoPartTimeReportPeriods)
            } else {
                return nil
            }
        }
        return Property(capturing: m)
    }()


    // MARK: - Actions that do most of the actual work

    internal lazy var actionRetrieveProfile = Action<(), Profile, APIAccessError>(unwrapping: urlSession) {
        $0.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)
    }

    internal lazy var actionRetrieveProjects: Action<(), IndexedProjects, APIAccessError> = {
        let execute: (URLSession, [WorkspaceID]) -> SignalProducer<IndexedProjects, APIAccessError> = {
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
        return Action<(), IndexedProjects, APIAccessError>(unwrapping: retrieveProjectsInput, execute: execute)
    }()

    internal lazy var actionRetrieveReports: Action<(), IndexedTwoPartTimeReports, APIAccessError> = {
        let execute: (URLSession, [WorkspaceID], TwoPartTimeReportPeriods) -> SignalProducer<IndexedTwoPartTimeReports, APIAccessError> = {
            (session, workspaceIDs, periods) in
            let workedUntilYesterday = workedTimesProducer(session: session, workspaceIDs: workspaceIDs, period: periods.previousToToday)
            let workedToday = workedTimesProducer(session: session, workspaceIDs: workspaceIDs, period: periods.today)
            return SignalProducer.combineLatest(workedUntilYesterday, workedToday, SignalProducer(value: periods.full))
                .map(generateIndexedReportsFromWorkedTimes)
        }
        return Action<(), IndexedTwoPartTimeReports, APIAccessError>(unwrapping: retrieveReportsInput, execute: execute)
    }()

    internal lazy var actionRetrieveRunningEntry = Action<(), RunningEntry?, APIAccessError>(unwrapping: urlSession) {
        $0.togglAPIRequestProducer(for: RunningEntryService.endpoint, decoder: RunningEntryService.decodeRunningEntry)
    }
}

extension Action where Input == () {
    func applyNextTimeEnabled() {
        self.isEnabled
            .producer
            .filter { $0 } // only trues
            .take(first: 1) // only first filtered value
            .map { _ in () }
            .startWithValues { [unowned self] in
                self.apply().start()
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
