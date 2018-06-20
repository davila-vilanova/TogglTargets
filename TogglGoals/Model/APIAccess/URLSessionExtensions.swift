//
//  URLSessionExtensions.swift
//  TogglGoals
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

internal var overrideRootAPIURLString: String? // e.g. "http://localhost:8080/toggl"

extension URLSession {
    convenience init(togglAPICredential: TogglAPICredential?) {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if let credential = togglAPICredential {
            let authHeaders: [String: String] = [ credential.authHeaderKey : credential.authHeaderValue ]
            config.httpAdditionalHeaders = authHeaders
        }
        self.init(configuration: config)
    }

    var isCredentialSet: Bool {
        return configuration.httpAdditionalHeaders != nil
    }

    func togglAPIRequestProducer(for endpoint: String) -> SignalProducer<(Data, URLResponse), APIAccessError> {
        guard isCredentialSet else {
            return SignalProducer(error: APIAccessError.noCredentials)
        }

        func resourceURL(for endpoint: String) -> URL {
            let rootAPIURLString = overrideRootAPIURLString ?? "https://toggl.com"
            let resourceURLString = rootAPIURLString + endpoint
            return URL(string: resourceURLString)!
        }

        func request(for path: String) -> URLRequest {
            return URLRequest(url: resourceURL(for: path))
        }

        return mapErrors(from: self.reactive.data(with: request(for: endpoint)))
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

fileprivate func mapErrors(from producer: SignalProducer<(Data, URLResponse), AnyError>)
    -> SignalProducer<(Data, URLResponse), APIAccessError> {
        return producer.mapError(wrapAnyErrorInLoadingSubsystemError)
            .attemptMap(catchHTTPErrors)
}

fileprivate func wrapAnyErrorInLoadingSubsystemError(_ err: AnyError) -> APIAccessError {
    return APIAccessError.loadingSubsystemError(underlyingError: err)
}

fileprivate func catchHTTPErrors(data: Data, response: URLResponse) -> Result<(Data, URLResponse), APIAccessError> {
    guard let httpResponse = response as? HTTPURLResponse else {
        return .failure(APIAccessError.nonHTTPResponseReceived(response: response))
    }
    switch (httpResponse.statusCode) {
    case 200...299, 100...199, 300...399: break
    case 401: return .failure(APIAccessError.authenticationError(response: httpResponse))
    case 500...599: return .failure(APIAccessError.serverHiccups(response: httpResponse, data: data))
    case 400...499: return .failure(APIAccessError.otherHTTPError(response: httpResponse))
    default: return .failure(APIAccessError.otherHTTPError(response: httpResponse))
    }
    return .success((data, httpResponse))
}
