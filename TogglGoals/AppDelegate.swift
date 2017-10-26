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
    private let userDefaults = UserDefaults()
    private let scheduler = QueueScheduler()

    private lazy var credentialStore = CredentialStore(userDefaults: userDefaults, scheduler: scheduler)

    lazy var credentialValidator = CredentialValidator()

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

        modelCoordinator.apiCredential <~ credentialStore.credential.producer.skipNil().map { $0 as TogglAPICredential }
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
        preferencesController.credentialDownstream <~ credentialStore.credential

        credentialValidator.credential <~ preferencesController.credentialUpstream.skipNil()
        preferencesController.credentialValidationResult <~ credentialValidator.validationResult

        let validationResult = credentialValidator.validationResult // TODO: may there be glitches if credential is set also from persistent storage?
            .map { validationResult -> TogglAPITokenCredential? in
                switch validationResult {
                case let .valid(credential): return credential
                default: return nil
                }
            }
            .skipNil()
        credentialStore.updater <~ SignalProducer(value: validationResult)
    }


    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === preferencesWindowController?.window {
            preferencesWindowController = nil
            credentialStore.updater <~ SignalProducer.never
        }
    }
}

fileprivate class CredentialStore {
    init(userDefaults: UserDefaults, scheduler: Scheduler) {
        self.userDefaults = userDefaults
        self.scheduler = scheduler

        let updater = _credentialUpdater.producer.skipNil().flatten(.latest)
        persistCredential <~ updater
        _latestKnownCredential <~ updater
    }

    lazy var credential = Property(_latestKnownCredential)
    var updater: BindingTarget<SignalProducer<TogglAPITokenCredential, NoError>> { return _credentialUpdater.deoptionalizedBindingTarget }

    private let userDefaults: UserDefaults
    private let scheduler: Scheduler

    private lazy var _latestKnownCredential: MutableProperty<TogglAPITokenCredential?> = {
        let initialCredentialValue = TogglAPITokenCredential(userDefaults: userDefaults)
        return MutableProperty(initialCredentialValue)
    }()

    private lazy var _credentialUpdater = MutableProperty<SignalProducer<TogglAPITokenCredential, NoError>?>(nil)

    private let (lifetime, token) = Lifetime.make()

    private lazy var persistCredential = BindingTarget<TogglAPITokenCredential>(on: scheduler, lifetime: lifetime) { [userDefaults] credential in
        credential.write(to: userDefaults)
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
