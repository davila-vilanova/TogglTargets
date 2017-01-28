//
//  NetworkOperation.swift
//  Sandbox
//
//  Created by David Davila on 12/01/2017.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class TogglAPIAccessingOperation<T>: Operation, URLSessionDataDelegate {
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
        } else {
            self.model = unmarshallModel(from: self.data)
        }
        isExecuting = false
        isFinished = true
    }

    // MARK: - URL
    let rootAPIURLString = "https://www.toggl.com/api/v8"

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

    func unmarshallModel(from data: Data) -> T? {
        assert(false, "override me in subclass")
        return nil
    }
}

class ProfileLoadingOperation: TogglAPIAccessingOperation<Profile> {
    override var endpointPath: String {
        get {
            return "/me?with_related_data=true"
        }
    }

    override func unmarshallModel(from data: Data) -> Profile? {
        let json = try! JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? Dictionary<String, Any>,
            let dataDict = dict["data"] as? Dictionary<String, Any> {
            return Profile.fromTogglAPI(dictionary: dataDict)
        }
        return nil
    }
}
