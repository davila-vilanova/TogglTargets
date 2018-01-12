//: Playground - noun: a place where people can play

import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

typealias SessionProducer = SignalProducer<URLSession, NoError>
typealias APIEntityProducer<EntityType> = SignalProducer<EntityType, APIAccessError>
typealias WorkspaceID = Int64
typealias ProjectID = Int64
typealias IndexedProjects = [ProjectID : Project]

/// Provides access to the Toggl API using an associated URLSession initialized with a TogglAPICredential
class AccessPerSession {
    let session: URLSession
    init(session: URLSession) {
        self.session = session
    }

    /// Returns a producer that emits the user's profile
    lazy var profileProducer: APIEntityProducer<Profile> = session.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)


    /// Returns a producer that emits an indexed collection of projects from all workspaces after the provided workspace IDs producer completes
    lazy var projectsProducer: APIEntityProducer<IndexedProjects> = {
        // will emit the workspace IDs associated with the user's profile
        let workspaceIDsProducer = profileProducer.map { SignalProducer($0.workspaces) }
            .flatten(.latest)
            .map { $0.id }

        // will emit an endpoint per workspace
        let endpointsProducer: APIEntityProducer<String> = workspaceIDsProducer.map(ProjectsService.endpoint)

        // will emit, per endpoint, a producer that emits a single array of projects or an error and then completes
        let projectsProducers: SignalProducer<APIEntityProducer<[Project]>, APIAccessError> = endpointsProducer
            .map { [session] endpoint in
                session.togglAPIRequestProducer(for: endpoint, decoder: ProjectsService.decodeProjects)
        }

        // will emit, as single value, a producer containing all projects after projectsProducers complete
        let allProjects = projectsProducers.flatten(.merge).reduce(into: [Project]()) { ( aggregated: inout [Project], projectsFromEndpoint: [Project]) in
            aggregated.append(contentsOf: projectsFromEndpoint)
        }

        return allProjects.map {
            var indexed = IndexedProjects()
            for project in $0 {
                indexed[project.id] = project
            }
            return indexed
        }
    }()
}

