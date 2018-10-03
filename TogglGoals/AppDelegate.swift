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
    private lazy var mainWindow: NSWindow = {
        let window = mainWindowController.window!
        window.delegate = self
        return window
    }()

    private var presentedPreferencesWindow: NSWindow?

    private let scheduler = QueueScheduler()

    private let currentDateGenerator = CurrentDateGenerator.shared
    private let calendar = Property(value: Calendar.iso8601)

    private let userDefaults = Property(value: UserDefaults.standard)
    private lazy var credentialStore = PreferenceStore<TogglAPITokenCredential>(userDefaults: userDefaults,
                                                                                scheduler: scheduler)
    private lazy var periodPreferenceStore = PreferenceStore<PeriodPreference>(userDefaults: userDefaults,
                                                                               scheduler: scheduler,
                                                                               defaultValue: PeriodPreference.monthly)
    private let (applicationLifetime, token) = Lifetime.make()

    private let modelCoordinator: ModelCoordinator

    private let undoManager = UndoManager()

    override init() {
        let supportDir: URL

        do {
            supportDir = try SupportDirectoryProvider.shared.appSupportDirectory()
        } catch {
            fatalError("Can't access app support directory")
        }

        if let goalsPersistenceProvider = SQLiteGoalPersistenceProvider(baseDirectory: supportDir),
            let cachePersistenceProvider = SQLiteTogglAPIDataPersistenceProvider(baseDirectory: supportDir) {
            let togglAPIDataCache = TogglAPIDataCache(persistenceProvider: cachePersistenceProvider)
            let togglAPIDataRetriever =
                CachedTogglAPIDataRetriever(retrieveProfileNetworkActionMaker: makeRetrieveProfileNetworkAction,
                                            retrieveProfileFromCache: togglAPIDataCache.retrieveProfile,
                                            storeProfileInCache: togglAPIDataCache.storeProfile,
                                            retrieveProjectsNetworkActionMaker: makeRetrieveProjectsNetworkAction,
                                            retrieveProjectsFromCache: togglAPIDataCache.retrieveProjects,
                                            storeProjectsInCache: togglAPIDataCache.storeProjects,
                                            retrieveReportsNetworkActionMaker: makeRetrieveReportsNetworkAction,
                                            retrieveRunningEntryNetworkActionMaker: makeRetrieveRunningEntryNetworkAction)

            let goalsStore = ConcreteProjectIDsByGoalsProducingGoalsStore(persistenceProvider: goalsPersistenceProvider, undoManager: undoManager)

            modelCoordinator = ModelCoordinator(togglDataRetriever: togglAPIDataRetriever,
                                                goalsStore: goalsStore,
                                                currentDateGenerator: currentDateGenerator,
                                                calendar: calendar.producer,
                                                reportPeriodsProducer: ReportPeriodsProducer())
            applicationLifetime.observeEnded {
                _ = togglAPIDataCache
            }
        } else {
            fatalError("Goals store failed to initialize")
        }

        super.init()

        modelCoordinator.periodPreference <~ periodPreferenceStore.output.producer.skipNil()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        processEnvironmentVariables()

        mainWindow.makeKeyAndOrderFront(nil)

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

        if credentialStore.output.value == nil {
            presentPreferences(jumpingTo: .account, asSheet: true)
        }
    }

    private func processEnvironmentVariables() {
        let environment = ProcessInfo.processInfo.environment
        if let customBaseTogglAPIURL = environment["customBaseTogglAPIURL"] {
            if URL(string: customBaseTogglAPIURL) != nil { // valid URL
                overrideRootAPIURLString = customBaseTogglAPIURL
                print("Using custom base Toggl API URL: \(customBaseTogglAPIURL)")
            } else {
                print("Ignoring invalid value of customBaseTogglAPIURL environment variable")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        userDefaults.value.synchronize()
    }

    @IBAction func presentPreferences(_ sender: Any) {
        presentPreferences()
    }

    private func presentPreferences(jumpingTo prefsSection: PreferencesViewController.Section? = nil,
                                    asSheet presentAsSheet: Bool = false) {
        assert(Thread.current.isMainThread)

        if let alreadyPresented = presentedPreferencesWindow {
            alreadyPresented.makeKeyAndOrderFront(nil)
            return
        }

        let preferencesStoryboard = NSStoryboard(name: .init("Preferences"), bundle: nil)
        let preferencesWindowController = preferencesStoryboard.instantiateInitialController() as! NSWindowController
        let preferencesWindow = preferencesWindowController.window!
        let preferencesController = (preferencesWindow.contentViewController as! PreferencesViewControllerWrapper)
        let lifetime = preferencesController.reactive.lifetime

        let resolvedCredential = MutableProperty<TogglAPITokenCredential?>(nil)
        let updatedPeriodPreference = MutableProperty<PeriodPreference?>(nil)

        lifetime.observeEnded {
            _ = resolvedCredential
            _ = updatedPeriodPreference
        }

        preferencesController <~ SignalProducer<PreferencesViewControllerWrapper.Interface, NoError>(
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

        if presentAsSheet {
            mainWindow.beginSheet(preferencesWindow) { [unowned self] response in
                self.presentedPreferencesWindow = nil
            }
        } else {
            preferencesWindow.delegate = self
            preferencesWindow.makeKeyAndOrderFront(nil)
        }

        presentedPreferencesWindow = preferencesWindow
    }

    func windowWillClose(_ notification: Notification) {
        if let closing = notification.object as? NSWindow,
            let prefsWindow = presentedPreferencesWindow,
            closing == prefsWindow {
            presentedPreferencesWindow = nil
        }
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        return window == mainWindow ? undoManager : nil
    }

    @IBAction func refreshAllData(_ sender: Any) {
        modelCoordinator.refreshAllData <~ SignalProducer(value: ())
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
