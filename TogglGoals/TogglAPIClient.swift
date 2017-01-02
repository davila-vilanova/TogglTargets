//
//  TogglAPIClient.swift
//  TogglGoals
//
//  Created by David Davila on 25/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import Alamofire

struct TogglAuth {
    let username: String?
    let password: String?
    let apiToken: String?

    init(username: String, password: String) {
        self.username = username
        self.password = password
        self.apiToken = nil
    }

    init(apiToken: String) {
        self.apiToken = apiToken
        self.username = nil
        self.password = nil
    }
}

typealias StringKeyedDictionary = Dictionary<String, Any>

extension Profile {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Profile? {
        if let id = dictionary["id"] as? Int64 {
            var profile = Profile(id: id)
            if let name = dictionary["fullname"] as? String {
                profile.name = name
            }
            if let email = dictionary["email"] as? String {
                profile.email = email
            }
            if let imageUrlString = dictionary["image_url"] as? String,
                let imageUrl = URL(string: imageUrlString) {
                profile.imageUrl = imageUrl
            }
            if let workspacesDictionaries = dictionary["workspaces"] as? [StringKeyedDictionary] {
                var workspaces = Array<Workspace>()
                for workspaceDictionary in workspacesDictionaries {
                    if let workspace = Workspace.fromTogglAPI(dictionary: workspaceDictionary) {
                        workspaces.append(workspace)
                    }
                }
            } // TODO: collapse these two into a generic function having Workpace and Project conform to a protocol that declares fromTogglAPI(dictionary:) -> (Protocol)
            if let projectsDictionaries = dictionary["projects"] as? [StringKeyedDictionary] {
                var projects = Array<Project>()
                for projectDictionary in projectsDictionaries {
                    if let project = Project.fromTogglAPI(dictionary: projectDictionary) {
                        projects.append(project)
                    }
                }
            }
            return profile
        } else {
            return nil
        }
    }
}

extension Workspace {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Workspace? {
        if let id = dictionary["id"] as? Int64 {
            var workspace = Workspace(id: id)
            if let name = dictionary["name"] as? String {
                workspace.name = name
            }
            return workspace
        } else {
            return nil
        }
    }
}

extension Project {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Project? {
        if let id = dictionary["id"] as? Int64 {
            var project = Project(id: id)
            if let name = dictionary["name"] as? String {
                project.name = name
            }
            if let active = dictionary["active"] as? Bool {
                project.active = active
            }
            if let workspaceId = dictionary["wid"] as? Int64 {
                project.workspaceId = workspaceId
            }
        }
        return nil
    }
}

typealias BackendProfileRetrievalCompletionHandler = (Profile?, Error?) -> ()

class TogglAPIClient {
    let auth: TogglAuth // TODO: will be var to allow for runtime setting of authentication credentials
    lazy var sessionManager: SessionManager = {
        let username, password: String
        if let token = self.auth.apiToken {
            username = token
            password = "api_token"
        } else {
            // TODO: handle error
            username = self.auth.username!
            password = self.auth.password!
        }

        let authorizationHeader = Request.authorizationHeader(user: username, password: password)! // TODO: handle error
        var headers: HTTPHeaders = [:]
        headers[authorizationHeader.key] = authorizationHeader.value
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = headers
        return Alamofire.SessionManager(configuration: configuration)
    }()

    init(auth: TogglAuth) {
        self.auth = auth
    }

    func retrieveUserProfile(queue: DispatchQueue, completion:@escaping BackendProfileRetrievalCompletionHandler) {
        sessionManager.request("https://www.toggl.com/api/v8/me")
            .responseJSON(queue: queue) { response in
                if let json = response.result.value as? StringKeyedDictionary,
                    let data = json["data"] as? StringKeyedDictionary {
                    if let profile = Profile.fromTogglAPI(dictionary: data) {
                        completion(profile, nil)
                    } // TODO: else handle error
                }  // TODO: else handle error
        }
    }
}
