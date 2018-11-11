//
//  URLSessionExtensions.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

internal var overrideRootAPIURLString: String? // e.g. "http://localhost:8080/toggl"

extension URLSession {

    /// Initializes a URL session configured with a credential to access the Toggl API.
    ///
    /// - parameters:
    ///   - togglAPICredential: The `TogglAPICredential` that this session will use to access the Toggl API.
    convenience init(togglAPICredential: TogglAPICredential?) {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if let credential = togglAPICredential {
            let authHeaders: [String: String] = [ credential.authHeaderKey: credential.authHeaderValue ]
            config.httpAdditionalHeaders = authHeaders
        }
        self.init(configuration: config)
    }

    /// Returns Determines whether this session is configured with a credential.
    var isCredentialSet: Bool {
        return configuration.httpAdditionalHeaders != nil // TODO: check for `Authentication` header
    }

    /// Creates a producer that when started will send a request to the provided endpoint in the Toggl API and will
    /// emit a single (`Data`, `URLResponse`) tuple value if successful or fail with an `APIAccessError` representing
    /// the underlying loading subsystem error or HTTP error.
    ///
    /// - parameters:
    ///   - endpoint: The endpoint to which to send the request
    ///
    ///   - returns: The created producer that will send the request upon start and it will emit a single value or an
    ///              error and then complete.
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

    /// Creates a producer that when started will send a request to the provided endpoint in the Toggl API and will
    /// emit a single (`U`, `URLResponse`) tuple value if successful retrieving and decoding the data into a `U` 
    /// datatype or fail with an `APIAccessError` representing the underlying loading subsystem error, HTTP error or
    /// JSON decoding error.
    ///
    /// - parameters:
    ///   - endpoint: The endpoint to which to send the request
    ///   - decoder: A function that takes a `Data` value enclosing a JSON string and decodes it into a `U` value or
    ///     throws an error if it fails to decode the JSON.
    ///
    ///   - returns: The created producer that will send the request upon start and it will emit a single value or an
    ///              error and then complete.
    func togglAPIRequestProducer<U>(for endpoint: String,
                                    decoder: @escaping ((Data, URLResponse) throws -> U))
        -> SignalProducer<U, APIAccessError> {
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

/// Transforms a producer of `(Data, URLResponse)` that can fail with `AnyError` (that is, the producer returned by
/// `URLSession.reactive.data(with:)`) into a producer that can fail only with an `APIAccessError`.
///
/// - parameters:
///   - producer: The producer to transform
///
///   - returns: A producer that can fail only with an `APIAccessError`.
private func mapErrors(from producer: SignalProducer<(Data, URLResponse), AnyError>)
    -> SignalProducer<(Data, URLResponse), APIAccessError> {
        return producer.mapError(wrapAnyErrorInLoadingSubsystemError)
            .attemptMap(catchHTTPErrors)
}

/// Wraps the provided error into an `APIAccessError.loadingSubsystemError`
///
/// - parameters:
///   - err: The error to wrap.
///
///   - returns: The wrapped error.
private func wrapAnyErrorInLoadingSubsystemError(_ err: AnyError) -> APIAccessError {
    return APIAccessError.loadingSubsystemError(underlyingError: err)
}

/// Takes a `Data` and a `URLResponse` pair of values and wraps them into a `Result` value. If the response is an
/// `HTTPURLResponse`, the returned `Result` will be `.success` or a `.failure` depending on the response's HTTP status
/// code. If the response is not HTTP, `.failure` will be returned. `.success` return values enclose the passed data and 
/// response.
private func catchHTTPErrors(data: Data, response: URLResponse) -> Result<(Data, URLResponse), APIAccessError> {
    guard let httpResponse = response as? HTTPURLResponse else {
        return .failure(APIAccessError.nonHTTPResponseReceived(response: response))
    }
    switch httpResponse.statusCode {
    case 200...299, 100...199, 300...399: break
    case 401, 403: return .failure(APIAccessError.authenticationError(response: httpResponse))
    case 500...599: return .failure(APIAccessError.serverHiccups(response: httpResponse, data: data))
    case 400...499: return .failure(APIAccessError.otherHTTPError(response: httpResponse))
    default: return .failure(APIAccessError.otherHTTPError(response: httpResponse))
    }
    return .success((data, httpResponse))
}
