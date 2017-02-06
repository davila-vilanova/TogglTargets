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
    let rootAPIURLString = "https://www.toggl.com"

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

class ProfileLoadingOperation: TogglAPIAccessingOperation<(Profile, [Workspace], [Project])> {
    override var endpointPath: String {
        get {
            return "/api/v8/me?with_related_data=true"
        }
    }

    override func unmarshallModel(from data: Data) -> (Profile, [Workspace], [Project])? {
        let json = try! JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? Dictionary<String, Any>,
            let dataDict = dict["data"] as? Dictionary<String, Any>,
            let profile = Profile.fromTogglAPI(dictionary: dataDict) {
                let workspaces = Workspace.collectionFromTogglAPI(dictionary: dataDict)
                let projects = Project.collectionFromTogglAPI(dictionary: dataDict)
            return (profile, workspaces, projects)
        }
        return nil
    }
}


internal class ReportsLoadingOperation: TogglAPIAccessingOperation<Dictionary<Int64, TimeReport>> {
    override var endpointPath: String {
        get {
            let since = "2017-01-01"
            let until = "2017-01-31"
            let userAgent = "david@davi.la"
            return "/reports/api/v2/summary?workspace_id=\(workspaceId)&since=\(since)&until=\(until)&grouping=projects&subgrouping=users&user_agent=\(userAgent)"
        }
    }

    let workspaceId: Int64

    init(credential: TogglAPICredential, workspaceId: Int64) {
        self.workspaceId = workspaceId
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
                    let report = TimeReport(projectId: projectId, workedTime: timeInterval)
                    timeReports[projectId] = report
                }
            }
        }

        return timeReports
    }
}

internal class ReportsLoadingTriggeringOperation: Operation {
    private var _profileLoadingOperation: ProfileLoadingOperation?
    private var profileLoadingOperation: ProfileLoadingOperation? {
        get {
            if _profileLoadingOperation == nil {
                for operation in dependencies {
                    if let profileOperation = operation as? ProfileLoadingOperation {
                        _profileLoadingOperation = profileOperation
                    }
                }
            }
            return _profileLoadingOperation
        }
    }

    private let credential: TogglAPICredential
    private let reportsCollectingOperation: ReportsCollectingOperation

    init(credential: TogglAPICredential, reportsCollectingOperation: ReportsCollectingOperation) {
        self.credential = credential
        self.reportsCollectingOperation = reportsCollectingOperation
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        guard profileLoadingOperation != nil else {
            return
        }

        let operation = profileLoadingOperation!

        if let workspaces = operation.model?.1 {
            for w in workspaces {
                let op = ReportsLoadingOperation(credential: credential, workspaceId: w.id)
                reportsCollectingOperation.addDependency(op)
                OperationQueue.current?.addOperation(op)
            }
        } else if let error = operation.error {
            // TODO
            print(error)
        } else {
            
        }
    }
}

internal class ReportsCollectingOperation: Operation {
    private var _reportsLoadingOperation: ReportsLoadingOperation?
    private var reportsLoadingOperation: ReportsLoadingOperation? {
        get {
            if _reportsLoadingOperation == nil {
                for operation in dependencies {
                    if let reportsOperation = operation as? ReportsLoadingOperation {
                        _reportsLoadingOperation = reportsOperation
                    }
                }
            }
            return _reportsLoadingOperation
        }
    }

    internal var collectedReports = Dictionary<Int64, TimeReport>()

    override func main() {
        guard !isCancelled else {
            return
        }

        guard reportsLoadingOperation != nil else {
            return
        }

        let operation = reportsLoadingOperation!

        if let reports = operation.model {
            for (projectId, report) in reports {
                collectedReports[projectId] = report
            }
        }
    }
}




