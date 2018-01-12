//: A Cocoa based Playground to present user interface

import AppKit
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport

func makeBlackBoxThatGeneratesSignalsWhenButtonPressed(_ button: NSButton) -> Signal<(), NoError> {
    let action = Action { SignalProducer(value: ()) }
    button.reactive.pressed = CocoaAction(action)
    return action.values
}


let nibFile = NSNib.Name(rawValue:"MyView")
var topLevelObjects : NSArray?

class Controller {
    let rootView = NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))

    let monthlyButton = NSButton(radioButtonWithTitle: "Monthly", target: nil, action: nil)
    let weeklyButton = NSButton(radioButtonWithTitle: "Weekly", target: nil, action: nil)
    let weekdaysPopup = NSPopUpButton(frame: CGRect(x: 0, y: 125, width: 400, height: 25))

    let inputPeriodPreference = PeriodPreference.weekly(startDay: .thursday)

    var outputPeriodPreference = MutableProperty<PeriodPreference?>(nil)

    init() {
        rootView.wantsLayer = true
        rootView.layer!.backgroundColor = CGColor.white

        monthlyButton.frame = CGRect(x: 0, y: 175, width: 400, height: 25)
        rootView.addSubview(monthlyButton)

        weeklyButton.frame = CGRect(x: 0, y: 150, width: 400, height: 25)
        rootView.addSubview(weeklyButton)

        rootView.addSubview(weekdaysPopup)

        let cal = Calendar(identifier: .iso8601)
        for weekday in Weekday.allDaysOrdered {
            weekdaysPopup.addItem(withTitle: cal.weekdaySymbols[weekday.indexInGregorianCalendarSymbolsArray])
        }

        PlaygroundPage.current.liveView = rootView

		func oppositeState(_ inputState: NSControl.StateValue) -> NSControl.StateValue {
			switch inputState {
			case .on:
				return .off
			case .off:
				return .on
			default:
				return .off
			}
		}

//        monthlyButton.reactive.state <~ SignalProducer(value: NSControl.StateValue.on)
		monthlyButton.reactive.state <~ weeklyButton.reactive.states.map(oppositeState)
		weeklyButton.reactive.state <~ monthlyButton.reactive.states.map(oppositeState)
    }
}

let controller = Controller()



extension NSButton {
    var pressedSignal: Signal<(), NoError> {
        return makeBlackBoxThatGeneratesSignalsWhenButtonPressed(self)
    }
}
