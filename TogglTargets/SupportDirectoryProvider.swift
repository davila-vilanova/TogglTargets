//
//  SupportDirectoryProvider.swift
//  TogglTargets
//
//  Created by David Dávila on 29.06.18.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// Retrieves and caches the app support directory.
class SupportDirectoryProvider {
    static var shared: SupportDirectoryProvider = { SupportDirectoryProvider() }()

    private let fileManager = FileManager.default

    private let defaultAppIdentifier = "la.davi.TogglTargets" // fallback if no bundle ID available
    private var cachedAppIdentifier: String?
    private var appIdentifier: String {
        if let identifier = cachedAppIdentifier {
            return identifier
        } else if let identifier = Bundle.main.bundleIdentifier {
            cachedAppIdentifier = identifier
            return identifier
        } else {
            return defaultAppIdentifier
        }
    }

    private var cachedAppSupportDirectory: URL?

    /// Retrieves this application's support directory.
    /// The name of the support directory specific to this application will match the application identifier,
    /// and it will be contained in the user's "Application Support" directory.
    ///
    /// If the directory does not exist this will attempt to create one. If creation fails, this will throw
    /// the error that prevented the creation.
    /// 
    /// - returns: The URL of the support directory specific to this application.
    func appSupportDirectory() throws -> URL {
        if let supportDir = cachedAppSupportDirectory {
            return supportDir
        }

        let userAppSupportDir = try fileManager.url(for: .applicationSupportDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                                    create: true)

        let supportDir = URL(fileURLWithPath: appIdentifier, relativeTo: userAppSupportDir)

        do {
            try _ = supportDir.checkResourceIsReachable()
        } catch {
            try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
        }

        cachedAppSupportDirectory = supportDir
        return supportDir
    }
}
