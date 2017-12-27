import AppKit
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true


enum RetrievalActivity {
    case profile
    case projects
    case reports
    case runningEntry
}

let retProfile = MutableProperty(false)
let retProjects = MutableProperty(false)


let currentActivities = MutableProperty([RetrievalActivity]())

currentActivities.producer.startWithValues {
    print($0)
}

currentActivities <~ SignalProducer.combineLatest(retProfile.producer, retProjects.producer)
    .map {
        let activities: [RetrievalActivity : Bool] = [
            .profile : $0.0,
            .projects : $0.1
        ]

        let f = activities.filter({ (_, isExecuting) -> Bool in
            return isExecuting
        })

        let m = f.keys

        return [RetrievalActivity](m)
}

retProfile.value = true

//let activityView = NSView(frame: NSRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 120, height: 25)))
//let activityDescription = NSTextField(string: "Retrieving profile")
//
////activityDescription.frame = NSRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 120, height: 25))
//
//activityView.addSubview(activityDescription)
//
//PlaygroundPage.current.liveView = activityView
print("yes, I'm running 1")

