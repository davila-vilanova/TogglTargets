//
//  AppDelegate.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    private lazy var mainStoryboard = NSStoryboard(name: .init("Main"), bundle: nil)
    private lazy var mainWindowController = mainStoryboard.instantiateInitialController() as! NSWindowController
    private var preferencesWindowController: NSWindowController?

    private let modelCoordinator: ModelCoordinator
    private let userDefaults = Property(value: UserDefaults.standard)
    private let scheduler = QueueScheduler()

    private lazy var credentialStore =
        PreferenceStore<TogglAPITokenCredential>(userDefaults: userDefaults, scheduler: scheduler)
    private lazy var periodPreferenceStore =
        PreferenceStore<PeriodPreference>(userDefaults: userDefaults, scheduler: scheduler)

    override init() {
        let supportDir: URL

        do {
            supportDir = try SupportDirectoryProvider.shared.appSupportDirectory()
        } catch {
            fatalError("Can't access app support directory")
        }

        if let goalsStore = SQLiteGoalsStore(baseDirectory: supportDir) {
            modelCoordinator =
                ModelCoordinator(retrieveProfileNetworkAction: makeRetrieveProfileNetworkAction(),
                                 retrieveProfileCacheAction: makeRetrieveProfileCacheAction(),
                                 storeProfileCacheAction: makeStoreProfileCacheAction(),
                                 retrieveProjectsNetworkAction: makeRetrieveProjectsNetworkAction(),
                                 retrieveReportsNetworkAction: makeRetrieveReportsNetworkAction(),
                                 retrieveRunningEntryNetworkAction: makeRetrieveRunningEntryNetworkAction(),
                                 goalsStore: goalsStore)
        } else {
            fatalError("Goals store failed to initialize")
        }

        super.init()

        modelCoordinator.apiCredential <~ credentialStore.output.producer.skipNil().map { $0 as TogglAPICredential }
        modelCoordinator.periodPreference <~ periodPreferenceStore.output.producer.skipNil()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainWindow = mainWindowController.window
        mainWindow!.makeKeyAndOrderFront(nil)

        if let masterDetailController = mainWindowController.window?.contentViewController as? ProjectsMasterDetailController {
            masterDetailController.now <~ modelCoordinator.now
            masterDetailController.calendar <~ modelCoordinator.calendar
            masterDetailController.periodPreference <~ periodPreferenceStore.output.producer.skipNil()

            masterDetailController.projects <~ modelCoordinator.projects.producer
            masterDetailController.goals <~ modelCoordinator.goals
            
            masterDetailController.setGoalActions(read: modelCoordinator.readGoalAction,
                                                  write: modelCoordinator.writeGoalAction,
                                                  delete: modelCoordinator.deleteGoalAction)
            masterDetailController.readReportAction = modelCoordinator.readReportAction
            
            masterDetailController.runningEntry <~ modelCoordinator.runningEntry
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        userDefaults.value.synchronize()
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

        preferencesController.userDefaults <~ userDefaults
        credentialStore.input <~ SignalProducer(value: preferencesController.resolvedCredential.skipNil())
        preferencesController.calendar <~ modelCoordinator.calendar
        preferencesController.now <~ modelCoordinator.now
        periodPreferenceStore.input <~ SignalProducer(value: preferencesController.updatedGoalPeriodPreference)
        preferencesController.existingGoalPeriodPreference <~ periodPreferenceStore.output.producer.skipNil()
    }


    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === preferencesWindowController?.window {
            preferencesWindowController = nil
            credentialStore.input <~ SignalProducer.never
            periodPreferenceStore.input <~ SignalProducer.never
        }
    }
}


// MARK: -

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
