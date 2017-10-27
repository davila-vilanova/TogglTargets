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

enum APIAccessError: Error {
    case loadingSubsystemError(underlyingError: Error)
    case nonHTTPResponseReceived(response: URLResponse)
    case authenticationError(response: HTTPURLResponse)
    case serverHiccups(response: HTTPURLResponse, data: Data)
    case otherHTTPError(response: HTTPURLResponse)
    case invalidJSON(underlyingError: Error, data: Data)
}

class TogglAPIAccess {
    private let scheduler = QueueScheduler.init(name: "TogglAPIAccess-scheduler")
    private let (lifetime, token) = Lifetime.make()

    // MARK: - Exposed inputs and outputs

    var apiCredential: BindingTarget<TogglAPICredential> { return _apiCredential.deoptionalizedBindingTarget }
    var reportsStartDate: BindingTarget<DayComponents> { return _reportsStartDate.deoptionalizedBindingTarget }
    var reportsEndDate: BindingTarget<DayComponents> { return _reportsEndDate.deoptionalizedBindingTarget }
    var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }
    lazy var retrieveRunningEntry = BindingTarget<()>(on: scheduler, lifetime: lifetime) { [unowned self] in self._retrieveRunningEntry() }

    lazy var profile = Property(_profile)
    lazy var projects = Property(_projects)
    lazy var reports = Property(_reports)
    lazy var runningEntry = Property(_runningEntry)


    // MARK: - Intermediary derived signals

    // sessions are available after credential is set
    private lazy var session: MutableProperty<URLSession?> = {
        let ses = MutableProperty<URLSession?>(nil)
        ses <~ _apiCredential.producer.skipNil().map { URLSession(togglAPICredential: $0) }
        return ses
    }()
    private lazy var sessionProducer = session.producer.skipNil()

    // workspaceIdsProducer will emit one value event per workspace ID
    private lazy var workspaceIdsProducer: SignalProducer<Int64, NoError> = _profile.producer.skipNil()
        .map { SignalProducer($0.workspaces) }
        .flatten(.latest)
        .map { $0.id }


    // MARK: - Backing of inputs

    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)
    private let _reportsStartDate = MutableProperty<DayComponents?>(nil)
    private let _reportsEndDate = MutableProperty<DayComponents?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _now = MutableProperty<Date?>(nil)


    // MARK: - Output wiring

    private lazy var _profile: MutableProperty<Profile?> = {
        let p = MutableProperty<Profile?>(nil)
        p <~ sessionProducer
            .start(on: scheduler)
            .map { $0.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile) }
            .flatten(.latest)
            .mapToNoError() // TODO: divert errors
        return p
    }()

    private lazy var _projects: MutableProperty<[Int64 : Project]> = {
        let p = MutableProperty([Int64 : Project]())
        // TODO: schedulers
        p <~ workspaceIdsProducer
            .map(ProjectsService.endpoint)
            .combineLatest(with: sessionProducer)
            .map { (endpoint, session) in
                session.togglAPIRequestProducer(for: endpoint, decoder: ProjectsService.decodeProjects)
            }.take(first: 1)
            .flatten(.latest)
            .mapToNoError()
            .reduce(into: [Int64 : Project](), { (indexedProjects, projects) in
                for project in projects {
                    indexedProjects[project.id] = project
                }
            })
        return p
    }()


    private lazy var _reports: MutableProperty<[Int64 : TwoPartTimeReport]> = {
        let p = MutableProperty([Int64 : TwoPartTimeReport]())

        /// TODO: describe how worked times are going to be merged in TwoPartTimeReport instances
        typealias IndexedWorkedTimes = [Int64 : TimeInterval]
        typealias WorkedTimesProducer = SignalProducer<IndexedWorkedTimes, APIAccessError>

        struct Period { // TODO: rename?
            let start: DayComponents
            let end: DayComponents
        }

        func workedTimesProducer(workspaceId: Int64, period: Period?) -> WorkedTimesProducer { // [1]
            guard let period = period else {
                return WorkedTimesProducer(value: IndexedWorkedTimes()) // empty
            }
            //     static func endpoint(workspaceId: Int64, since: String, until: String, userAgent: String) -> String {

            let endpoint = ReportsService.endpoint(workspaceId: workspaceId,
                                                   since: period.start.iso8601String, until: period.end.iso8601String,
                                                   userAgent: UserAgent)
            return sessionProducer.filter { $0.canAccessTogglReportsAPI }.map { [endpoint] (session) in
                session.togglAPIRequestProducer(for: endpoint, decoder: ReportsService.decodeReportEntries)
                }.flatten(.latest)
                .take(first: 1)
                .reduce(into: IndexedWorkedTimes()) { (indexedWorkedTimeEntries, reportEntries) in
                    for entry in reportEntries {
                        indexedWorkedTimeEntries[entry.id] = TimeInterval.from(milliseconds: entry.time)
                    }
            }
        }

        let todayProducer: SignalProducer<DayComponents, NoError>
            = SignalProducer.combineLatest(_calendar.producer.skipNil(), _now.producer.skipNil())
                .map { (calendar, now) in
                    return calendar.dayComponents(from: now)
        }
        let yesterdayProducer: SignalProducer<DayComponents?, NoError>
            = SignalProducer.combineLatest(_calendar.producer.skipNil(),
                                           _now.producer.skipNil(),
                                           _reportsStartDate.producer.skipNil())
                .map { (calendar, now, startDate) in
                    return try? calendar.previousDay(for: now, notBefore: startDate)
        }

        let previousToTodayPeriodProducer: SignalProducer<Period?, NoError> =
            SignalProducer.combineLatest(_reportsStartDate.producer.skipNil(), yesterdayProducer)
                .map { (start, yesterdayOrNil) in
                    if let yesterday = yesterdayOrNil {
                        return Period(start: start, end: yesterday)
                    } else {
                        return nil
                    }
        }
        let todayPeriodProducer: SignalProducer<Period, NoError> =
            todayProducer.map { Period(start: $0, end: $0)
        }

        let previousToTodayWorkedTimesProducer: WorkedTimesProducer = // [C]
            SignalProducer.combineLatest(workspaceIdsProducer, previousToTodayPeriodProducer)
                .map {  workedTimesProducer(workspaceId: $0, period: $1) }
                .flatten(.latest)

        let todayWorkedTimesProducer: WorkedTimesProducer = // [C]
            SignalProducer.combineLatest(workspaceIdsProducer, todayPeriodProducer)
                .map { workedTimesProducer(workspaceId: $0, period: $1) }
                .flatten(.latest)

        func generateIndexedReportsFromWorkedTimes(untilPreviousDay: IndexedWorkedTimes, today: IndexedWorkedTimes, period: Period) -> [Int64 : TwoPartTimeReport] {
            var reports = [Int64 : TwoPartTimeReport]()
            let ids: Set<Int64> = Set<Int64>(untilPreviousDay.keys).union(today.keys)
            for id in ids {
                let timeWorkedPreviousToToday: TimeInterval = untilPreviousDay[id] ?? 0.0
                let timeWorkedToday: TimeInterval = today[id] ?? 0.0
                reports[id] = TwoPartTimeReport(projectId: id,
                                                since: period.start,
                                                until: period.end,
                                                workedTimeUntilYesterday: timeWorkedPreviousToToday,
                                                workedTimeToday: timeWorkedToday)
            }
            return reports
        }

        p <~ SignalProducer.combineLatest(previousToTodayWorkedTimesProducer.mapToNoError(),
                                          todayWorkedTimesProducer.mapToNoError(),
                                          _reportsStartDate.producer.skipNil(),
                                          _reportsEndDate.producer.skipNil())
            .map { generateIndexedReportsFromWorkedTimes(untilPreviousDay: $0, today: $1, period: Period(start: $2, end: $3)) }

        return p
    }()

    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private func _retrieveRunningEntry() {
        _runningEntry <~ sessionProducer.take(first: 1).map { (session) in
            session.togglAPIRequestProducer(for: RunningEntryService.endpoint,
                                            decoder: RunningEntryService.decodeRunningEntry)
            .mapToNoError()
        }.flatten(.latest)
    }
}

class CredentialValidator {
    enum ValidationResult {
        case valid(TogglAPITokenCredential)
        case invalid
        /// Error other than authentication error
        case error(APIAccessError)
    }

    var credential: BindingTarget<TogglAPICredential> { return _credential.deoptionalizedBindingTarget }
    private let _credential = MutableProperty<TogglAPICredential?>(nil)

    lazy var validationResult: Signal<ValidationResult, NoError> = {
        let session = _credential.signal.skipNil().map { credential -> URLSession in
            return URLSession(togglAPICredential: credential)
        }

        let profileProducers: Signal<SignalProducer<Profile, APIAccessError>, NoError> =
            session.map { $0.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile) }

        // Take a producer that generates a single value of type profile or triggers an error
        // Return a producer that generates a single value of type Result that can contain a profile value or an error
        func redirectErrorToValue(producerWithError: SignalProducer<Profile, APIAccessError>)
            -> SignalProducer<Result<Profile, APIAccessError>, NoError> {
                return producerWithError.materialize().map { event -> Result<Profile, APIAccessError>? in
                    switch event {
                    case let .value(val): return Result<Profile, APIAccessError>(value: val)
                    case let .failed(err): return Result<Profile, APIAccessError>(error: err)
                    default: return nil
                    }
                    }.skipNil()
        }

        let profileOrErrorProducers = profileProducers.map(redirectErrorToValue)

        let validationResult = profileOrErrorProducers.flatten(.latest)
            .map { (result) -> ValidationResult in
                switch result {
                case let .success(profile): return ValidationResult.valid(TogglAPITokenCredential(apiToken: profile.apiToken!))
                case .failure(.authenticationError): return ValidationResult.invalid
                case let .failure(apiAccessError): return ValidationResult.error(apiAccessError)
                }
            }

        return validationResult
    }()
}


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

fileprivate let UserAgent = "david@davi.la"

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



