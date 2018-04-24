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
    private let (lifetime, token) = Lifetime.make()

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
                CachedTogglAPIDataRetriever(retrieveProfileNetworkActionMaker: makeRetrieveProfileNetworkAction,
                                            retrieveProfileCacheAction: makeRetrieveProfileCacheAction(),
                                            storeProfileCacheAction: makeStoreProfileCacheAction(),
                                            retrieveProjectsNetworkActionMaker: makeRetrieveProjectsNetworkAction,
                                            retrieveReportsNetworkActionMaker: makeRetrieveReportsNetworkAction,
                                            retrieveRunningEntryNetworkActionMaker: makeRetrieveRunningEntryNetworkAction)

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
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainWindow = mainWindowController.window
        mainWindow!.makeKeyAndOrderFront(nil)

        let controller = mainWindowController.window?.contentViewController as! ProjectsMasterDetailController
        controller <~ SignalProducer(
            value: (calendar: calendar.producer,
                    periodPreference: periodPreferenceStore.output.producer.skipNil(),
                    projectIDsByGoals: modelCoordinator.projectIDsByGoals,
                    runningEntry: modelCoordinator.runningEntry.producer,
                    currentDate: currentDateGenerator.currentDate.producer,
                    modelRetrievalStatus: modelCoordinator.retrievalStatus,
                    readProject: modelCoordinator.readProject,
                    readGoal: modelCoordinator.readGoal,
                    writeGoal: modelCoordinator.writeGoal,
                    deleteGoal: modelCoordinator.deleteGoal,
                    readReport: modelCoordinator.readReport))

        modelCoordinator.apiCredential <~ credentialStore.output.producer.skipNil().map { $0 as TogglAPICredential }
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

        let resolvedCredential = MutableProperty<TogglAPITokenCredential?>(nil)
        let updatedPeriodPreference = MutableProperty<PeriodPreference?>(nil)
        lifetime.observeEnded {
            _ = updatedPeriodPreference
        }

        preferencesController <~ SignalProducer<PreferencesViewController.Interface, NoError>(
            value: (periodPreferenceStore.output.producer.skipNil(),
                    userDefaults.producer,
                    calendar.producer,
                    currentDateGenerator.currentDate.producer,
                    resolvedCredential.deoptionalizedBindingTarget,
                    updatedPeriodPreference.deoptionalizedBindingTarget))

        credentialStore.input <~ SignalProducer(value: resolvedCredential.signal.skipNil())
        periodPreferenceStore.input <~ SignalProducer(value: updatedPeriodPreference.signal.skipNil())
    }

    @IBAction func refreshAllData(_ sender: Any) {
        modelCoordinator.refreshAllData <~ SignalProducer(value: ())
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
