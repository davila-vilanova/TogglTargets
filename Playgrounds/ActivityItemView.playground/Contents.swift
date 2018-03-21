import Cocoa
@testable import TogglGoals_MacOS

import PlaygroundSupport

let frame = CGRect(origin: NSZeroPoint,
                   size: NSSize(width: 240, height: 30))

let activityItem = ActivityCollectionViewItem()
activityItem.representedObject = ActivityStatus.executing(.syncProfile)

let activityView = activityItem.view
activityView.frame = frame

PlaygroundPage.current.liveView = activityView


print(Date())
