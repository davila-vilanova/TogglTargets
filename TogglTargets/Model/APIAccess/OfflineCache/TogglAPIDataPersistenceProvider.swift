//
//  TogglAPIDataPersistenceProvider.swift
//  TogglTargets
//
//  Created by David Dávila on 28.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import SQLite

/// The inteface of an entity taht can persist, delete and retrieve the user's Toggl profile and projects.
protocol TogglAPIDataPersistenceProvider {
    /// Persists the user's Toggl profile in the local storage.
    func persist(profile: Profile)

    /// Retrieves the locally stored user profile, or nil if no user profile is stored. 
    func retrieveProfile() -> Profile?

    /// Removes the user profile from local storage.
    func deleteProfile()

    /// Stores the user's projects in local storage.
    func persist(projects: [Project])

    /// Retrieves the locally stored user's projects, or nil if the user projects are not stored.
    func retrieveProjects() -> [Project]?

    /// Removes the user's projects from local storage.
    func deleteProjects()
}

/// An implementation of `TogglAPIDataPersistenceProvider` that uses a SQLite database. 
class SQLiteTogglAPIDataPersistenceProvider: TogglAPIDataPersistenceProvider {
    private let databaseConnection: Connection

    private let profileTable = Table("profile")
    private let profileIdExpression = Expression<Int64>("id")
    private let userNameExpression = Expression<String?>("name")
    private let emailExpression = Expression<String>("email")
    private let timezoneExpression = Expression<String?>("timezone")

    private let projectTable = Table("project")
    private let projectIdExpression = Expression<Int64>("id")
    private let projectNameExpression = Expression<String?>("name")
    private let workspaceIdExpression = Expression<WorkspaceID?>("workspace_id")

    init?(baseDirectory: URL?) {
        do {
            let databaseURL = URL(fileURLWithPath: "cached_toggl_data.sqlite3", relativeTo: baseDirectory)
            databaseConnection = try Connection(databaseURL.absoluteString)
        } catch {
            return nil
        }

        ensureSchemaCreated()
    }

    private func ensureSchemaCreated() {
        do {
            try databaseConnection.run(profileTable.create(ifNotExists: true) { tableBuilder in
                tableBuilder.column(profileIdExpression, primaryKey: true)
                tableBuilder.column(userNameExpression)
                tableBuilder.column(emailExpression)
                tableBuilder.column(timezoneExpression)
            })

            try databaseConnection.run(projectTable.create(ifNotExists: true) { tableBuilder in
                tableBuilder.column(projectIdExpression, primaryKey: true)
                tableBuilder.column(projectNameExpression)
                tableBuilder.column(workspaceIdExpression)
            })
        } catch let error {
            print("Failed to ensure that schema is created - error=\(error)")
        }
    }

    func persist(profile: Profile) {
        do {
            try databaseConnection.transaction {
                try databaseConnection.run(profileTable.delete())
                try databaseConnection.run(profileTable.insert(or: .replace,
                                               profileIdExpression <- profile.id,
                                               userNameExpression <- profile.name,
                                               emailExpression <- profile.email,
                                               timezoneExpression <- profile.timezone))
            }
        } catch let error {
            print("Failed to persist profile - error=\(error)")
        }
    }

    func retrieveProfile() -> Profile? {
        let rows = try? databaseConnection.prepare(profileTable.limit(1))
        guard let row = rows?.makeIterator().next() else {
            return nil
        }
        return Profile(id: row[profileIdExpression],
                       name: row[userNameExpression],
                       email: row[emailExpression],
                       imageUrl: nil,
                       timezone: row[timezoneExpression],
                       workspaces: [],
                       apiToken: nil)
    }

    func deleteProfile() {
        do {
            try databaseConnection.run(profileTable.delete())
        } catch let error {
            print("Failed to delete profile - error=\(error)")
        }
    }

    func persist(projects: [Project]) {
        do {
            try databaseConnection.run(projectTable.delete())
            try databaseConnection.transaction {
                for project in projects {
                    try databaseConnection.run(projectTable.insert(or: .replace,
                                                   projectIdExpression <- project.id,
                                                   projectNameExpression <- project.name,
                                                   workspaceIdExpression <- project.workspaceId))
                }
            }
        } catch let error {
            print("Failed to persist projects - error=\(error)")
        }
    }

    func retrieveProjects() -> [Project]? {
        guard let rows = try? databaseConnection.prepare(projectTable) else {
            return nil
        }

        var projects = [Project]()
        for row in rows {
            projects.append(Project(id: row[projectIdExpression],
                                    name: row[projectNameExpression],
                                    active: nil,
                                    workspaceId: row[workspaceIdExpression]))
        }

        guard projects.count > 0 else {
            return nil
        }

        return projects
    }

    func deleteProjects() {
        do {
            try databaseConnection.run(projectTable.delete())
        } catch let error {
            print("Failed to delete projects - error=\(error)")
        }
    }
}
