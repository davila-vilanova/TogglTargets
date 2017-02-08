//
//  TogglAPIAccessOperation.swift
//  TogglGoals
//
//  Created by David Davila on 06.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class TogglAPIAccessOperation<T>: Operation, URLSessionDataDelegate {
    private let lock = NSRecursiveLock()

    private var session: URLSession?

    // MARK: - Authentication
    private let apiCredential: TogglAPICredential

    var task: URLSessionDataTask?

    init(credential: TogglAPICredential) {
        self.apiCredential = credential
    }

    // MARK - NSOperation
    override func start() {
        lock.lock()
        defer { lock.unlock() }

        if (isCancelled) {
            return
        }

        isExecuting = true

        let config = URLSessionConfiguration.default
        var authHeaders = Dictionary<String, String>()
        authHeaders[apiCredential.authHeaderKey] = apiCredential.authHeaderValue
        config.httpAdditionalHeaders = authHeaders

        let s = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        session = s

        let t = s.dataTask(with: resourceURL)
        task = t

        t.resume()
    }

    override var isAsynchronous: Bool { get { return true } }

    private var _isExecuting = false
    override internal(set) var isExecuting: Bool {
        get {
            return _isExecuting
        }
        set {
            lock.lock()
            defer { lock.unlock() }

            if newValue == _isExecuting {
                return
            }

            willChangeValue(forKey: "isExecuting")
            _isExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _isFinished = false
    override internal(set) var isFinished: Bool {
        get {
            return _isFinished
        }
        set {
            lock.lock()
            defer { lock.unlock() }

            if newValue == _isFinished {
                return
            }

            willChangeValue(forKey: "isFinished")
            _isFinished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }

    // MARK: - URLSessionDataDelegate
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response

        if isCancelled {
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if isCancelled {
            dataTask.cancel()
        } else {
            self.data.append(data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let e = error {
            self.error = e
            onError?(e)
        } else {
            self.model = unmarshallModel(from: self.data)
            if let model = self.model {
                onSuccess?(model)
            } else {
                // TODO: trigger error. Let unmarshallModel throw error above.
            }
        }
        isExecuting = false
        isFinished = true
    }

    // MARK: - URL
    internal let rootAPIURLString = "https://www.toggl.com"
    internal let apiV8Path = "/api/v8"
    internal let reportsAPIV2Path = "/reports/api/v2"

    var endpointPath: String {
        get {
            assert(false, "override me in subclass")
            return ""
        }
    }

    var resourceURL: URL {
        get {
            let resourceURLString = rootAPIURLString + endpointPath
            return URL(string: resourceURLString)!
        }
    }

    // MARK: - Output
    var response: URLResponse?
    var data: Data = Data()
    var error: Error?
    var model: T?

    var onError: ( (Error) -> () )?
    var onSuccess: ( (T) -> () )?

    func unmarshallModel(from data: Data) -> T? {
        assert(false, "override me in subclass")
        return nil
    }
}
