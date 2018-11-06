//
//  TogglAPIDataPersistenceProvider.swift
//  TogglTargets
//
//  Created by David Dávila on 28.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import SQLite

protocol TogglAPIDataPersistenceProvider {
    func persist(profile: Profile)
    func retrieveProfile() -> Profile?
    func deleteProfile()
    func persist(projects: [Project])
    func retrieveProjects() -> [Project]?
    func deleteProjects()
}

class SQLiteTogglAPIDataPersistenceProvider: TogglAPIDataPersistenceProvider {
    private let db: Connection

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
            db = try Connection(databaseURL.absoluteString)
        } catch {
            return nil
        }

        ensureSchemaCreated()
    }

    private func ensureSchemaCreated() {
        do {
            try db.run(profileTable.create(ifNotExists: true) { t in
                t.column(profileIdExpression, primaryKey: true)
                t.column(userNameExpression)
                t.column(emailExpression)
                t.column(timezoneExpression)
            })

            try db.run(projectTable.create(ifNotExists: true) { t in
                t.column(projectIdExpression, primaryKey: true)
                t.column(projectNameExpression)
                t.column(workspaceIdExpression)
            })
        } catch let error {
            print("Failed to ensure that schema is created - error=\(error)")
        }
    }

    func persist(profile: Profile) {
        do {
            try db.transaction {
                try db.run(profileTable.delete())
                try db.run(profileTable.insert(or: .replace,
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
        let rows = try? db.prepare(profileTable.limit(1))
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
            try db.run(profileTable.delete())
        } catch let error {
            print("Failed to delete profile - error=\(error)")
        }
    }

    func persist(projects: [Project]) {
        do {
            try db.run(projectTable.delete())
            try db.transaction {
                for project in projects {
                    try db.run(projectTable.insert(or: .replace,
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
        guard let rows = try? db.prepare(projectTable) else {
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
            try db.run(projectTable.delete())
        } catch let error {
            print("Failed to delete projects - error=\(error)")
        }
    }
}
