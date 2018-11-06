//
//  AppDelegate.swift
//  TogglTargets
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

private let defaults = UserDefaults.standard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSUserInterfaceValidations {

    private lazy var mainStoryboard = NSStoryboard(name: "Main", bundle: nil)
    // swiftlint:disable:next force_cast
    private lazy var mainWindowController = mainStoryboard.instantiateInitialController() as! NSWindowController
    private lazy var mainViewController: ProjectsMasterDetailController =
        mainWindowController.window?.contentViewController as! ProjectsMasterDetailController
    // swiftlint:disable:previous force_cast
    private lazy var mainWindow: NSWindow = {
        let window = mainWindowController.window!
        window.delegate = self
        return window
    }()

    private var presentedPreferencesWindow: NSWindow?

    private let scheduler = QueueScheduler()

    private let currentDateGenerator = CurrentDateGenerator.shared
    private let calendar = Property(value: Calendar.iso8601)

    private let userDefaults = Property(value: defaults)
    private lazy var credentialStore = PreferenceStore<TogglAPITokenCredential>(userDefaults: userDefaults,
                                                                                scheduler: scheduler)
    private lazy var periodPreferenceStore = PreferenceStore<PeriodPreference>(userDefaults: userDefaults,
                                                                               scheduler: scheduler,
                                                                               defaultValue: PeriodPreference.monthly)
    private let (applicationLifetime, token) = Lifetime.make()

    private let modelCoordinator: ModelCoordinator

    private let undoManager = UndoManager()

    private var onboardingGuide: OnboardingGuide?

    private var mustSetupAccount: Bool {
        return credentialStore.output.value == nil
    }

    override init() {
        let supportDir: URL

        do {
            supportDir = try SupportDirectoryProvider.shared.appSupportDirectory()
        } catch {
            fatalError("Can't access app support directory")
        }

        if let timeTargetsPersistenceProvider = SQLiteTimeTargetPersistenceProvider(baseDirectory: supportDir),
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
            // swiftlint:disable:previous line_length
            
            let timeTargetsStore =
                ConcreteProjectIDsProducingTimeTargetsStore(persistenceProvider: timeTargetsPersistenceProvider,
                                                            undoManager: undoManager)

            modelCoordinator = ModelCoordinator(togglDataRetriever: togglAPIDataRetriever,
                                                timeTargetsStore: timeTargetsStore,
                                                currentDateGenerator: currentDateGenerator,
                                                calendar: calendar.producer,
                                                reportPeriodsProducer: ReportPeriodsProducer())
            applicationLifetime.observeEnded {
                _ = togglAPIDataCache
            }
        } else {
            fatalError("Time targets store failed to initialize")
        }

        super.init()

        modelCoordinator.periodPreference <~ periodPreferenceStore.output.producer.skipNil()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        processEnvironmentVariables()

        mainViewController <~ SignalProducer(
            value: (calendar: calendar.producer,
                    periodPreference: periodPreferenceStore.output.producer.skipNil(),
                    projectIDsByTimeTargets: modelCoordinator.projectIDsByTimeTargets,
                    runningEntry: modelCoordinator.runningEntry.producer,
                    currentDate: currentDateGenerator.currentDate.producer,
                    modelRetrievalStatus: modelCoordinator.retrievalStatus,
                    readProject: modelCoordinator.readProject,
                    readTimeTarget: modelCoordinator.readTimeTarget,
                    writeTimeTarget: modelCoordinator.writeTimeTarget,
                    deleteTimeTarget: modelCoordinator.deleteTimeTarget,
                    readReport: modelCoordinator.readReport))

        modelCoordinator.apiCredential <~ credentialStore.output.producer.map { $0 as TogglAPICredential? }

        NotificationCenter.default.addObserver(forName: ConfigureUserAccountRequestedNotificationName,
                                               object: nil,
                                               queue: OperationQueue.main,
                                               using: { _ in self.presentPreferences(jumpingTo: .account) })

        func showMainWindow(startOnboarding: Bool) {
            mainWindow.makeKeyAndOrderFront(nil)
            if mustSetupAccount {
                presentPreferences(jumpingTo: .account, asSheet: true)
            }
            if startOnboarding {
                self.startOnboarding()
            }
        }

        if shouldStartOnboarding {
            let welcomeStoryboard = NSStoryboard(name: "Welcome", bundle: nil)
            // swiftlint:disable:next force_cast
            let welcomeWindowController = welcomeStoryboard.instantiateInitialController() as! NSWindowController
            let welcomeWindow = welcomeWindowController.window!
            // swiftlint:disable:next force_cast
            let welcomeController = welcomeWindow.contentViewController as! WelcomeViewController

            BindingTarget(on: UIScheduler(), lifetime: welcomeWindow.reactive.lifetime) {
                welcomeWindow.close()
                showMainWindow(startOnboarding: true)
            } <~ welcomeController.continuePressed

            welcomeWindow.makeKeyAndOrderFront(self)
        } else {
            showMainWindow(startOnboarding: false)
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

        let preferencesStoryboard = NSStoryboard(name: "Preferences", bundle: nil)
        // swiftlint:disable:next force_cast
        let preferencesWindowController = preferencesStoryboard.instantiateInitialController() as! NSWindowController
        let preferencesWindow = preferencesWindowController.window!
        // swiftlint:disable:next force_cast
        let preferencesController = (preferencesWindow.contentViewController as! PreferencesViewControllerWrapper)
        let lifetime = preferencesController.reactive.lifetime

        let resolvedCredential = MutableProperty<TogglAPITokenCredential?>(nil)
        let updatedPeriodPreference = MutableProperty<PeriodPreference?>(nil)

        lifetime.observeEnded {
            _ = resolvedCredential
            _ = updatedPeriodPreference
        }

        let authErrors = modelCoordinator.retrievalStatus.filter { $0.isError }.filterMap { $0.error }.filter {
            switch $0 {
            case .noCredentials, .authenticationError: return true
            default: return false
            }
        }

        preferencesController <~ SignalProducer<PreferencesViewControllerWrapper.Interface, NoError>(
            value: (displaySection: SignalProducer(value: prefsSection),
                    existingCredential: credentialStore.output.producer,
                    profile: modelCoordinator.profile.producer.skipNil(),
                    apiAccessError: authErrors,
                    resolvedCredential: resolvedCredential.bindingTarget,
                    testURLSessionAction: makeRetrieveProfileNetworkAction(),
                    existingTimeTargetPeriodPreference: periodPreferenceStore.output.producer.skipNil(),
                    calendar: calendar.producer,
                    currentDate: currentDateGenerator.currentDate.producer,
                    updatedTimeTargetPeriodPreference: updatedPeriodPreference.deoptionalizedBindingTarget))

        lifetime += credentialStore.input <~ resolvedCredential.signal
        lifetime += periodPreferenceStore.input <~ updatedPeriodPreference.signal

        if presentAsSheet {
            mainWindow.beginSheet(preferencesWindow) { [unowned self] _ in
                self.presentedPreferencesWindow = nil
            }
        } else {
            preferencesWindow.delegate = self
            preferencesWindow.makeKeyAndOrderFront(nil)
        }

        // Reload profile if user is logged in --
        // this tests that the credentials keep being valid and takes the latest changes in the user's profile
        if credentialStore.output.value != nil {
            modelCoordinator.refreshAllData <~ SignalProducer(value: ())
        }

        presentedPreferencesWindow = preferencesWindow
    }

    @IBAction func orderFrontAboutPanel(_ sender: Any) {
        let aboutStoryboard = NSStoryboard(name: "About", bundle: nil)
        // swiftlint:disable:next force_cast
        let aboutWindowController = aboutStoryboard.instantiateInitialController() as! NSWindowController
        let aboutWindow = aboutWindowController.window!
        aboutWindow.delegate = self
        aboutWindow.makeKeyAndOrderFront(sender)
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

    private var shouldStartOnboarding: Bool {
        return OnboardingGuide.shouldOnboard(defaults) &&
            !isCurrentlyOnboarding
    }

    private var isCurrentlyOnboarding: Bool {
        return onboardingGuide != nil
    }

    @IBAction func startOnboarding(_ sender: Any?) {
        guard !isCurrentlyOnboarding else {
            return
        }
        if mustSetupAccount {
            presentPreferences(jumpingTo: .account, asSheet: true)
        }
        startOnboarding()
    }

    public func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(startOnboarding(_:)) {
            return !isCurrentlyOnboarding
        } else {
            return true
        }
    }

    private func startOnboarding() {
        let initialRelevantStep: OnboardingStepIdentifier = mustSetupAccount ? .login : .selectProject
        let guide = OnboardingGuide(steps: onboardingSteps(startingFrom: initialRelevantStep), defaults: defaults)

        self.onboardingGuide = guide
        reactive.makeBindingTarget { appDelegate, _ in appDelegate.onboardingGuide = nil } <~ guide.onboardingEnded

        mainViewController.setOnboardingGuide(guide)
        presentedPreferencesWindow?.contentViewController?.setOnboardingGuide(guide)
    }
}

private func resetOnboardingState() {
    defaults.removeObject(forKey: "OnboardingNotPending")
}
