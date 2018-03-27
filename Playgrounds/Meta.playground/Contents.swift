import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

let rootView = NSView()
rootView.frame = CGRect(origin: NSZeroPoint,
                        size: NSSize(width: 200, height: 80))
rootView.translatesAutoresizingMaskIntoConstraints = false
rootView.heightAnchor.constraint(equalToConstant: 200).isActive = true
rootView.widthAnchor.constraint(equalToConstant: 200).isActive = true

rootView.wantsLayer = true
rootView.layer!.backgroundColor = CGColor.init(red: 0, green: 1, blue: 0, alpha: 1)

PlaygroundPage.current.liveView = rootView

let contained = NSView()
contained.translatesAutoresizingMaskIntoConstraints = false
contained.wantsLayer = true
contained.layer!.backgroundColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1)

rootView.addSubview(contained)
contained.topAnchor.constraint(equalTo: rootView.topAnchor).isActive = true
contained.bottomAnchor.constraint(equalTo: rootView.bottomAnchor).isActive = true
contained.leadingAnchor.constraint(equalTo: rootView.leadingAnchor).isActive = true
contained.trailingAnchor.constraint(equalTo: rootView.trailingAnchor).isActive = true

print(Date())
