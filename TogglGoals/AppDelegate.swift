//
//  AppDelegate.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var modelCoordinator: ModelCoordinator

    override init() {
        let supportDir: URL

        do {
            supportDir = try SupportDirectoryProvider.shared.appSupportDirectory()
        } catch {
            fatalError("Can't access app support directory")
        }

        let modelCache = ModelCache()
        if let goalsStore = GoalsStore(baseDirectory: supportDir) {
            modelCoordinator = ModelCoordinator(cache: modelCache, goalsStore: goalsStore)
        } else {
            fatalError("Goals store failed to initialize")
        }

        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        modelCoordinator.startRefreshingRunningTimeEntry()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
//        modelCoordinator?.refreshRunningTimeEntry()
    }

    func applicationWillResignActive(_ notification: Notification) {
//        modelCoordinator?.stopRefreshingRunningTimeEntry()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

fileprivate class SupportDirectoryProvider {
    static var shared: SupportDirectoryProvider = { SupportDirectoryProvider() }()

    private let fileManager = FileManager.default

    private let defaultAppIdentifier = "la.davi.TogglGoals" // fallback if no bundle ID available
    private var _appIdentifier: String?
    private var appIdentifier: String {
        get {
            if let identifier = _appIdentifier {
                return identifier
            } else if let identifier = Bundle.main.bundleIdentifier {
                _appIdentifier = identifier
                return identifier
            } else {
                return defaultAppIdentifier
            }
        }
    }

    private var _appSupportDirectory: URL?
    func appSupportDirectory() throws -> URL {
        if let supportDir = _appSupportDirectory {
            return supportDir
        }

        let userAppSupportDir = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        let supportDir = URL(fileURLWithPath: appIdentifier, relativeTo: userAppSupportDir)

        do {
            try _ = supportDir.checkResourceIsReachable()
        } catch {
            try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
        }

        _appSupportDirectory = supportDir
        return supportDir
    }
}
