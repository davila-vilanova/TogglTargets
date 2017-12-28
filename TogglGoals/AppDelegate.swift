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

    private let scheduler = QueueScheduler()

    private let currentDateGenerator = CurrentDateGenerator.shared
    private let calendar = Property(value: Calendar.iso8601)

    private let userDefaults = Property(value: UserDefaults.standard)
    private lazy var credentialStore = PreferenceStore<TogglAPITokenCredential>(userDefaults: userDefaults,
                                                                                scheduler: scheduler)
    private lazy var periodPreferenceStore = PreferenceStore<PeriodPreference>(userDefaults: userDefaults,
                                                                               scheduler: scheduler)

    private let modelCoordinator: ModelCoordinator

    override init() {
        let supportDir: URL

        do {
            supportDir = try SupportDirectoryProvider.shared.appSupportDirectory()
        } catch {
            fatalError("Can't access app support directory")
        }

        if let goalsStore = SQLiteGoalsStore(baseDirectory: supportDir) {
            let togglAPIDataRetriever =
                CachedTogglAPIDataRetriever(retrieveProfileNetworkAction: makeRetrieveProfileNetworkAction(),
                                            retrieveProfileCacheAction: makeRetrieveProfileCacheAction(),
                                            storeProfileCacheAction: makeStoreProfileCacheAction(),
                                            retrieveProjectsNetworkActionMaker: makeRetrieveProjectsNetworkAction,
                                            retrieveReportsNetworkActionMaker: makeRetrieveReportsNetworkAction,
                                            retrieveRunningEntryNetworkAction: makeRetrieveRunningEntryNetworkAction())

            modelCoordinator = ModelCoordinator(togglDataRetriever: togglAPIDataRetriever,
                                                goalsStore: goalsStore,
                                                currentDateGenerator: currentDateGenerator,
                                                reportPeriodsProducer: ReportPeriodsProducer())
        } else {
            fatalError("Goals store failed to initialize")
        }

        super.init()

        modelCoordinator.calendar <~ calendar
        modelCoordinator.periodPreference <~ periodPreferenceStore.output.producer.skipNil()
        modelCoordinator.apiCredential <~ credentialStore.output.producer.skipNil().map { $0 as TogglAPICredential }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainWindow = mainWindowController.window
        mainWindow!.makeKeyAndOrderFront(nil)

        if let controller = mainWindowController.window?.contentViewController as? ProjectsMasterDetailController {
            controller.currentDate <~ currentDateGenerator.currentDate
            controller.calendar <~ calendar
            controller.periodPreference <~ periodPreferenceStore.output.producer.skipNil()
            controller.runningEntry <~ modelCoordinator.runningEntry
            controller.runningActivities <~ modelCoordinator.currentActivities
            controller.apiAccessErrors <~ modelCoordinator.apiAccessErrors.logEvents(identifier: "apiAccessErrors")

            controller.setActions(fetchProjectIDs: modelCoordinator.fetchProjectIDsByGoalsAction,
                                  readProject: modelCoordinator.readProjectAction,
                                  readGoal: modelCoordinator.readGoalAction,
                                  writeGoal: modelCoordinator.writeGoalAction,
                                  deleteGoal: modelCoordinator.deleteGoalAction,
                                  readReport: modelCoordinator.readReportAction)
            
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
        preferencesController.calendar <~ calendar
        preferencesController.currentDate <~ currentDateGenerator.currentDate
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
