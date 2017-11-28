//
//  RetrieveProjectsNetworkAction.swift
//  TogglGoals
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

typealias RetrieveProjectsNetworkAction = Action<(URLSession, [WorkspaceID]), IndexedProjects, APIAccessError>
func makeRetrieveProjectsNetworkAction() -> RetrieveProjectsNetworkAction {
    return RetrieveProjectsNetworkAction { (session, workspaceIDs) in
        let workspaceIDsProducer = SignalProducer(workspaceIDs) // will emit one value per workspace ID
        let projectsProducer: SignalProducer<[Project], APIAccessError> =
            workspaceIDsProducer
                .map(ProjectsService.endpoint)
                .map { [session] endpoint in
                    session.togglAPIRequestProducer(for: endpoint, decoder: ProjectsService.decodeProjects)
                } // will emit one [Project] producer per endpoint, then complete
                .flatten(.concat)

        return projectsProducer.reduce(into: IndexedProjects()) { (indexedProjects, projects) in
            for project in projects {
                indexedProjects[project.id] = project
            }
        }
    }
}

fileprivate struct ProjectsService {
    static func endpoint(for workspaceId: Int64) -> String {
        return "/api/v8/workspaces/\(workspaceId)/projects"
    }

    static func decodeProjects(data: Data, response: URLResponse) throws -> [Project] {
        return try JSONDecoder().decode([Project].self, from: data)
    }
}
