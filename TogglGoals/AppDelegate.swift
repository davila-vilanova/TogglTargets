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
    private lazy var mainViewController: ProjectsMasterDetailController = mainWindowController.window?.contentViewController as! ProjectsMasterDetailController

    private var presentedPreferencesWindow: NSWindow?

    private let scheduler = QueueScheduler()

    private let currentDateGenerator = CurrentDateGenerator.shared
    private let calendar = Property(value: Calendar.iso8601)

    private let userDefaults = Property(value: UserDefaults.standard)
    private lazy var credentialStore = PreferenceStore<TogglAPITokenCredential>(userDefaults: userDefaults,
                                                                                scheduler: scheduler)
    private lazy var periodPreferenceStore = PreferenceStore<PeriodPreference>(userDefaults: userDefaults,
                                                                               scheduler: scheduler)
    private let (applicationLifetime, token) = Lifetime.make()

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
                                            retrieveProjectsCacheAction: makeRetrieveProjectsCacheAction(),
                                            storeProjectsCacheAction: makeStoreProjectsCacheAction(),
                                            retrieveReportsNetworkActionMaker: makeRetrieveReportsNetworkAction,
                                            retrieveRunningEntryNetworkActionMaker: makeRetrieveRunningEntryNetworkAction)

            modelCoordinator = ModelCoordinator(togglDataRetriever: togglAPIDataRetriever,
                                                goalsStore: goalsStore,
                                                currentDateGenerator: currentDateGenerator,
                                                calendar: calendar.producer,
                                                reportPeriodsProducer: ReportPeriodsProducer())
        } else {
            fatalError("Goals store failed to initialize")
        }

        super.init()

        modelCoordinator.periodPreference <~ periodPreferenceStore.output.producer.skipNil()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        processLaunchArguments()

        let mainWindow = mainWindowController.window
        mainWindow!.makeKeyAndOrderFront(nil)

        mainViewController <~ SignalProducer(
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

        modelCoordinator.apiCredential <~ credentialStore.output.producer.map { $0 as TogglAPICredential? }

        NotificationCenter.default.addObserver(forName: ConfigureUserAccountRequestedNotificationName,
                                               object: nil,
                                               queue: OperationQueue.main,
                                               using: { _ in self.presentPreferences(jumpingTo: .account) })
    }

    private func processLaunchArguments() {
        let environment = ProcessInfo.processInfo.environment
        if let customBaseTogglAPIURL = environment["customBaseTogglAPIURL"] {
            if URL(string: customBaseTogglAPIURL) != nil { // valid URL
                overrideRootAPIURLString = customBaseTogglAPIURL
                print ("Using custom base Toggl API URL: \(customBaseTogglAPIURL)")
            } else {
                print ("Ignoring invalid value of customBaseTogglAPIURL environment variable")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        userDefaults.value.synchronize()
    }

    @IBAction func presentPreferences(_ sender: Any) {
        presentPreferences()
    }

    private func presentPreferences(jumpingTo prefsSection: PreferencesViewController.Section? = nil) {
        assert(Thread.current.isMainThread)

        if let alreadyPresented = presentedPreferencesWindow {
            alreadyPresented.makeKeyAndOrderFront(nil)
            return
        }

        let preferencesStoryboard = NSStoryboard(name: .init("Preferences"), bundle: nil)
        let windowController = preferencesStoryboard.instantiateInitialController() as! NSWindowController
        let window = windowController.window!
        let preferencesController = (window.contentViewController as! PreferencesViewController)
        let lifetime = preferencesController.lifetime

        let resolvedCredential = MutableProperty<TogglAPITokenCredential?>(nil)
        let updatedPeriodPreference = MutableProperty<PeriodPreference?>(nil)

        lifetime.observeEnded {
            _ = resolvedCredential
            _ = updatedPeriodPreference
        }

        preferencesController <~ SignalProducer<PreferencesViewController.Interface, NoError>(
            value: (displaySection: SignalProducer(value: prefsSection),
                    existingCredential: credentialStore.output.producer,
                    resolvedCredential: resolvedCredential.bindingTarget,
                    testURLSessionAction: makeTestURLSessionNetworkAction(),
                    existingGoalPeriodPreference: periodPreferenceStore.output.producer.skipNil(),
                    calendar: calendar.producer,
                    currentDate: currentDateGenerator.currentDate.producer,
                    updatedGoalPeriodPreference: updatedPeriodPreference.deoptionalizedBindingTarget))

        lifetime += credentialStore.input <~ resolvedCredential.signal
        lifetime += periodPreferenceStore.input <~ updatedPeriodPreference.signal

        window.makeKeyAndOrderFront(nil)
        window.delegate = self
        presentedPreferencesWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        // Only expecting the preferences window to notify of close
        presentedPreferencesWindow = nil
    }

    @IBAction func refreshAllData(_ sender: Any) {
        modelCoordinator.refreshAllData <~ SignalProducer(value: ())
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
