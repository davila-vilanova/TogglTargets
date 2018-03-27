import Cocoa
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport


let width: CGFloat = 175
let itemHeight: CGFloat = 30
let rootFrame = CGRect(origin: NSZeroPoint,
                   size: NSSize(width: width, height: itemHeight * 4))

var gray: CGFloat = 0.8

let kHeightConstraintIdentifier = "HeightConstraintIdentifier"
let kAnimationDuration = 0.10

extension NSView {
    func constraintWithIdentifier(_ identifier: String) -> NSLayoutConstraint? {
        for constraint in constraints {
            if constraint.identifier == identifier {
                return constraint
            }
        }
        return nil
    }
}

func makeContainerView() -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer!.backgroundColor = CGColor.init(gray: gray, alpha: 1)
    gray -= 0.2
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}

func attachContainerView(_ containerView: NSView, to superview: NSView, under previousView: NSView? = nil) {
    superview.addSubview(containerView)
    containerView.leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive = true
    containerView.trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true

    containerView.topAnchor.constraint(equalTo: (previousView?.bottomAnchor ?? superview.topAnchor)).isActive = true

    let heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 0)
    heightConstraint.identifier = kHeightConstraintIdentifier
    heightConstraint.isActive = true
}

func attachActivityView(_ activityView: NSView, to containerView: NSView) {
    activityView.translatesAutoresizingMaskIntoConstraints = false
    NSAnimationContext.beginGrouping()
    NSAnimationContext.current.duration = kAnimationDuration
    containerView.animator().addSubview(activityView)
    containerView.constraintWithIdentifier(kHeightConstraintIdentifier)!.animator().constant = itemHeight
    NSAnimationContext.endGrouping()

    activityView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
    activityView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
    activityView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
    activityView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
}

func detachActivityView(_ activityView: NSView) {
    guard let superview = activityView.superview else {
        return
    }
    NSAnimationContext.beginGrouping()
    NSAnimationContext.current.duration = kAnimationDuration
    NSAnimationContext.current.completionHandler = {
        activityView.removeFromSuperview()
    }
    superview.constraintWithIdentifier(kHeightConstraintIdentifier)!.animator().constant = 0
    NSAnimationContext.endGrouping()
}

let profileContainer = makeContainerView()
let projectsContainer = makeContainerView()
let reportsContainer = makeContainerView()
let runningEntryContainer = makeContainerView()

let rootView = NSView()
rootView.frame = rootFrame
rootView.wantsLayer = true
rootView.layer!.backgroundColor = CGColor.init(red: 0, green: 1, blue: 0, alpha: 1)

PlaygroundPage.current.liveView = rootView
PlaygroundPage.current.needsIndefiniteExecution = true

attachContainerView(profileContainer, to: rootView)
attachContainerView(projectsContainer, to: rootView, under: profileContainer)
attachContainerView(reportsContainer, to: rootView, under: projectsContainer)
attachContainerView(runningEntryContainer, to: rootView, under: reportsContainer)

let syncProfileActivityItem = ActivityCollectionViewItem()
let syncProjectsActivityItem = ActivityCollectionViewItem()
let syncReportsActivityItem = ActivityCollectionViewItem()
let syncRunningEntryActivityItem = ActivityCollectionViewItem()

syncProfileActivityItem.representedObject = ActivityStatus.executing(.syncProfile)
syncProjectsActivityItem.representedObject =  ActivityStatus.executing(.syncProjects)
syncReportsActivityItem.representedObject = ActivityStatus.executing(.syncReports)
syncRunningEntryActivityItem.representedObject = ActivityStatus.executing(.syncRunningEntry)


class Target {
    var action: (() -> ())

    init(_ action: @escaping () -> ()) {
        self.action = action
    }

    @objc
    func triggerAction(_ sender: Any) {
        action()
    }
}
var clickCount = 0
let clickTarget = Target() {
    clickCount += 1
    switch clickCount {
    case 1: attachActivityView(syncRunningEntryActivityItem.view, to: runningEntryContainer)
    case 2: attachActivityView(syncProfileActivityItem.view, to: profileContainer)
    case 3: attachActivityView(syncReportsActivityItem.view, to: reportsContainer)
    case 4: attachActivityView(syncProjectsActivityItem.view, to: projectsContainer)
    case 5: detachActivityView(syncReportsActivityItem.view)
    case 6: detachActivityView(syncRunningEntryActivityItem.view)
    case 7: detachActivityView(syncProfileActivityItem.view)
    case 8: detachActivityView(syncProjectsActivityItem.view)
    default: break
    }
}

let clickRecognizer = NSClickGestureRecognizer()
clickRecognizer.target = clickTarget
clickRecognizer.action = #selector(Target.triggerAction(_:))
rootView.addGestureRecognizer(clickRecognizer)


print(Date())
