//
//  RetrieveProjectsNetworkAction.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

/// Action that takes an array of `WorkspaceID` values, retrieves from the Toggl
///  API the projects corresponding to each workspace and merges them in an
/// `IndexedProjects` dictionary.
typealias RetrieveProjectsNetworkAction = Action<([WorkspaceID]), IndexedProjects, APIAccessError>

/// A function or closure that takes a `Property` that holds and tracks changes
/// to a `URLSession` optional value and generates an `Action` that can be used
/// to retrieve projects from the Toggl API, combine and index them, and is
/// enabled whenever the the provided `Property` holds a non-`nil` value.
///
/// This can be used to inject a `RetrieveProjectsNetworkAction` into an entity
/// that needs to make the `Action` depend on the state of its `URLSession`.
typealias RetrieveProjectsNetworkActionMaker = (Property<URLSession?>) -> RetrieveProjectsNetworkAction

/// A concrete, non-mock implementation of `RetrieveProjectsNetworkActionMaker`.
func makeRetrieveProjectsNetworkAction(_ urlSession: Property<URLSession?>) -> RetrieveProjectsNetworkAction {
    let networkRetriever = { (endpoint: String, session: URLSession) in
        session.togglAPIRequestProducer(for: endpoint, decoder: ProjectsService.decodeProjects)
    }
    return makeRetrieveProjectsNetworkAction(urlSession, networkRetriever)
}

/// Takes a property holding an optional `URLSession` and a `TogglAPINetworkRetriever`
/// that retrieves one array of projects for one endpoint and a `URLSession` value,
/// and returns a `RetrieveProjectsNetworkAction` that applies request splitting,
/// projects combining and indexing logic on top of them.
///
/// - parameters:
///   - urlSession: A `Property` that holds and tracks changes to a `URLSession`
///                 optional value and is used as the state of the returned `Action`
///   - networkRetriever: A `TogglAPINetworkRetriever` that retrieves an array of
///                       `Project` values from an input Toggl API endpoint.
///
/// - returns: A `RetrieveProjectsNetworkAction` that applies request splitting,
///            projects combining and indexing logic on top of the provided
///            `URLSession` and `TogglAPINetworkRetriever`.
func makeRetrieveProjectsNetworkAction(_ urlSession: Property<URLSession?>, _ networkRetriever: @escaping TogglAPINetworkRetriever<[Project]>) -> RetrieveProjectsNetworkAction {
    return RetrieveProjectsNetworkAction(unwrapping: urlSession) { (session, workspaceIDs) in
        let workspaceIDsProducer = SignalProducer(workspaceIDs) // will emit one value per workspace ID
        let projectsProducer: SignalProducer<[Project], APIAccessError> =
            workspaceIDsProducer
                .map(ProjectsService.endpoint)
                .map { [networkRetriever, session] endpoint in networkRetriever(endpoint, session) }
                .flatten(.concat)

        return projectsProducer.reduce(into: IndexedProjects()) { (indexedProjects, projects) in
            for project in projects {
                indexedProjects[project.id] = project
            }
        }
    }
}

private struct ProjectsService {

    static func endpoint(for workspaceId: WorkspaceID) -> String {
        return "/api/v8/workspaces/\(workspaceId)/projects"
    }

    static func decodeProjects(data: Data, response: URLResponse) throws -> [Project] {
        return try JSONDecoder().decode([Project].self, from: data)
    }
}
