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

extension URLSession {
    convenience init(togglAPICredential: TogglAPICredential) {
        let authHeaders: [String: String] = [ togglAPICredential.authHeaderKey : togglAPICredential.authHeaderValue ]
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = authHeaders
        self.init(configuration: config)
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
//            .logEvents(identifier: "request for \(endpoint)")
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

let UserAgent = "david@davi.la"

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

