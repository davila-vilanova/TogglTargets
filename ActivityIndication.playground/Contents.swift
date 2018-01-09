import AppKit
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
let request = URLRequest(url: URL(string: "http://davi.la:8080/toggl/api/v8/me")!)
let task = session.dataTask(with: request) { data, response, error in
    print("data: \(data != nil ? "some data" : "nil"), response: \(response != nil ? "some response" : "nil"), error: \(String(describing: error))")
}
task.resume()

print(Date())

