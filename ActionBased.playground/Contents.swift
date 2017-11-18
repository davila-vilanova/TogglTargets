import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport


//
//
//
//
//
//let reportPeriodsProducer = ReportPeriodsProducer()
//reportPeriodsProducer.startDate <~ SignalProducer(value: DayComponents(year: 2017, month: 11, day: 1))
//reportPeriodsProducer.endDate <~ SignalProducer(value: DayComponents(year: 2017, month: 11, day: 30))
//reportPeriodsProducer.calendar <~ SignalProducer(value: Calendar(identifier: .iso8601))
//reportPeriodsProducer.now <~ SignalProducer(value: Date())
//
//let apiAccess = APIAccess(reportPeriodsProducer: reportPeriodsProducer)
//let credential = TogglAPITokenCredential(apiToken: "8e536ec872a3900a616198ecb3415c03")!
//apiAccess.apiCredential <~ SignalProducer<TogglAPICredential, NoError>(value: credential)
//
//let rootView = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
//rootView.wantsLayer = true; rootView.layer!.backgroundColor = CGColor.white
//PlaygroundPage.current.liveView = rootView
//
//let nameLabel = NSTextField(frame: CGRect(x: 10, y: 165, width: 280, height: 25))
//nameLabel.backgroundColor = NSColor.black
//nameLabel.reactive.text <~ SignalProducer(value: "name label")
//rootView.addSubview(nameLabel)
//
//let errorLabel = NSTextField(frame: CGRect(x: 10, y: 140, width: 280, height: 25))
//errorLabel.backgroundColor = NSColor.black
//errorLabel.reactive.text <~ SignalProducer(value: "error label")
//rootView.addSubview(errorLabel)
//
//let retryButton = NSButton(frame: CGRect(x: 10, y: 110, width: 100, height: 25))
//retryButton.title = "retry"
//rootView.addSubview(retryButton)
//
//let retrieveProfileAction = Action {
//    apiAccess.makeProfileProducer()
//        .take(first: 1)
//        .flatten(.latest)
//}
//
//retryButton.reactive.pressed = CocoaAction(retrieveProfileAction)
//
//nameLabel.reactive.text <~ retrieveProfileAction.values
//    .map { $0.name! }
//errorLabel.reactive.text <~ retrieveProfileAction.errors
//    .map { "\($0)" }
//
//retrieveProfileAction.apply().start()
//
//let retrieveReportsAction = Action {
//    apiAccess.makeReportsProducer()
//        .take(first: 1)
//        .flatten(.latest)
//}
//
//let reportsProp = MutableProperty<IndexedTwoPartTimeReports?>(nil)
//
//reportsProp <~ retrieveReportsAction.values.logEvents(identifier: "retrieveReportsAction")
//
//retrieveReportsAction.apply().start()

