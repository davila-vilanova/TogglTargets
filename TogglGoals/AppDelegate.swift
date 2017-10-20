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
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    private lazy var mainStoryboard = NSStoryboard(name: .init("Main"), bundle: nil)
    private lazy var mainWindowController = mainStoryboard.instantiateInitialController() as! NSWindowController
    private var preferencesWindowController: NSWindowController?

    private let modelCoordinator: ModelCoordinator
    private let userDefaults = UserDefaults()
    private let togglAPICredential = MutableProperty<TogglAPICredential?>(nil)

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

        togglAPICredential.value = TogglAPITokenCredential(apiToken: "8e536ec872a3900a616198ecb3415c03")
//        togglAPICredential.value = TogglAPIUsernameCredential(username: "david@davi.la", password: "Go$zKDMKAcGmKByl7rwbE3MMMpKnAvKsz5rycpAI|usGsvBU1A")
        modelCoordinator.apiCredential <~ togglAPICredential
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainWindow = mainWindowController.window
        mainWindow!.makeKeyAndOrderFront(nil)

        if let masterDetailController = mainWindowController.window?.contentViewController as? ProjectsMasterDetailController {
            masterDetailController.now <~ modelCoordinator.now
            masterDetailController.calendar <~ modelCoordinator.calendar
            
            masterDetailController.projects <~ modelCoordinator.projects
            masterDetailController.goals <~ modelCoordinator.goals
            
            masterDetailController.goalReadProviderProducer = modelCoordinator.goalReadProviderProducer
            masterDetailController.goalWriteProviderProducer = modelCoordinator.goalWriteProviderProducer
            masterDetailController.reportReadProviderProducer = modelCoordinator.reportReadProviderProducer
            
            masterDetailController.runningEntry <~ modelCoordinator.runningEntry
        }

        modelCoordinator.forceRefreshRunningEntry()
    }

    @IBAction func openPreferencesWindow(_ sender: Any) {
        guard preferencesWindowController == nil else {
            return
        }
        let preferencesStoryboard = NSStoryboard(name: .init("Preferences"), bundle: nil)
        preferencesWindowController = (preferencesStoryboard.instantiateInitialController() as! NSWindowController)
        let preferencesWindow = preferencesWindowController!.window!
        preferencesWindow.makeKeyAndOrderFront(nil)
        preferencesWindow.delegate = self

        let preferencesController = preferencesWindowController!.contentViewController! as! PreferencesViewController
        preferencesController.credentialDownstream <~ togglAPICredential
        togglAPICredential <~ preferencesController.credentialUpstream.logEvents(identifier: "credentialUpstream")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === preferencesWindowController?.window {
            preferencesWindowController = nil
        }
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
