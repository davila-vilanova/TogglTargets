//
//  ProjectDetailsViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import PureLayout
import ReactiveSwift
import ReactiveCocoa
import Result

fileprivate let GoalVCContainment = "GoalVCContainment"
fileprivate let GoalReportVCContainment = "GoalReportVCContainment"
fileprivate let NoGoalVCContainment = "NoGoalVCContainment"

class ProjectDetailsViewController: NSViewController, ViewControllerContaining {

    // MARK: - Exposed targets

    internal var project: BindingTarget<Project> { return _project.deoptionalizedBindingTarget }
    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }
    internal var calendar: BindingTarget<Calendar> { return _calendar.deoptionalizedBindingTarget }
    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }


    // MARK: - Private properties

    private let _project = MutableProperty<Project?>(nil)
    private let _now = MutableProperty<Date?>(nil)
    private let _calendar = MutableProperty<Calendar?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)

    private var currentUpstreamGoalBindingDisposable: Disposable?

    /// goalDownstream holds and propagates the values read by this controller and subcontrollers
    /// of the currently selected goal, if any.
    private let goalDownstream = MutableProperty<Goal?>(nil)

    /// goalUpstream relays the edits on the goal and goal deletion outputted by goalViewController
    /// and the freshly created goal outputsetContainedViewControllerted by noGoalViewController
    private let goalUpstream = MutableProperty<Goal?>(nil)


    // MARK: - Derived input

    private lazy var projectId: SignalProducer<Int64, NoError> = _project.producer.skipNil().map { $0.id }


    // MARK: - Goal and report providing

    /// Each start invocation of this producer and its siblings (goalWriteProviderProducer and reportReadProviderProducer)
    /// must deliver one and only one value which is an action taking a project ID as its input
    internal var goalReadProviderProducer: SignalProducer<Action<Int64, Property<Goal?>, NoError>, NoError>! {
        didSet {
            assert(goalReadProviderProducer != nil)
            assert(oldValue == nil)
            if let producer = goalReadProviderProducer {
                goalReadProvider <~ producer.take(first: 1)
            }
        }
    }
    private let goalReadProvider = MutableProperty<Action<Int64, Property<Goal?>, NoError>?>(nil)

    internal var goalWriteProviderProducer: SignalProducer<Action<Int64, BindingTarget<Goal?>, NoError>, NoError>! {
        didSet {
            assert(goalWriteProviderProducer != nil)
            assert(oldValue == nil)
            if let producer = goalWriteProviderProducer {
                goalWriteProvider <~ producer.take(first: 1)
            }
        }
    }
    private let goalWriteProvider = MutableProperty<Action<Int64, BindingTarget<Goal?>, NoError>?>(nil)

    internal var reportReadProviderProducer: SignalProducer<Action<Int64, Property<TwoPartTimeReport?>, NoError>, NoError>! {
        didSet {
            assert(reportReadProviderProducer != nil)
            assert(oldValue == nil)
            if let producer = reportReadProviderProducer {
                reportReadProvider <~ producer.take(first: 1)
            }
        }
    }
    private let reportReadProvider = MutableProperty<Action<Int64, Property<TwoPartTimeReport?>, NoError>?>(nil)

    private func setupConnectionsWithProviders() {
        goalReadProvider.producer.skipNil().take(first: 1) // A single, non-nil provider is expected during the controller lifecycle
            .startWithValues { [unowned self] (action) in
                // This ensures that goalDownstream will listen to changes of only the current project
                self.goalDownstream <~ action.values.flatten(.latest)
                action <~ self.projectId // Each time there is a change in project ID a different project is displayed
        }

        goalWriteProvider.producer.skipNil().take(first: 1).startWithValues { [unowned self] (action) in
            action.values.observeValues { (upstream) in
                // Propagate updated upstream values of goal to only the latest provided, current-goal pointing target
                if let previousDisposable = self.currentUpstreamGoalBindingDisposable {
                    previousDisposable.dispose()
                }
                // Important, if subtle: connect the _signal_ of goalUpstream to the provided target, not the producer.
                // The producer will relay the last known value and that will be nil if this is the first time a goal is connected
                // or the value of the previously connected goal otherwise. Connecting the signal ensures that only subsequent
                // updates will be relayed upstream.
                self.currentUpstreamGoalBindingDisposable = upstream <~ self.goalUpstream.signal
            }
            action <~ self.projectId
        }

        reportReadProvider.producer.skipNil().take(first: 1).startWithValues { [unowned self] (action) in
            self.goalReportViewController.report <~ action.values.flatten(.latest)
            action <~ self.projectId
        }
    }


    // MARK: - Local use of project

    private func setupLocalProjectDisplay() {
        _project.producer.observe(on: UIScheduler()).startWithValues { [unowned self] projectOrNil in
            self.projectName.stringValue = projectOrNil?.name ?? (projectOrNil != nil ? "(unnamed project)" : "(no project selected)")
        }
    }


    // MARK: - Contained view controllers

    var goalViewController: GoalViewController! {
        didSet {
            if let controller = goalViewController {
                controller.goal <~ goalDownstream
                goalUpstream <~ controller.userUpdates
                controller.calendar <~ _calendar.producer.skipNil()
            }
        }
    }

    var goalReportViewController: GoalReportViewController! {
        didSet {
            if let controller = goalReportViewController {
                controller.projectId <~ projectId
                controller.now <~ _now.producer.skipNil()
                controller.goal <~ goalDownstream.producer.skipNil()
                controller.calendar <~ _calendar.producer.skipNil()
                controller.runningEntry <~ _runningEntry.producer.skipNil()
            }
        }
    }

    var noGoalViewController: NoGoalViewController! {
        didSet {
            if let controller = noGoalViewController {
                controller.projectId <~ projectId
                // NoGoalViewController can output only non-optional goals as its output job is to send a freshly created
                // goal through the channel or to not send anything. However, goalUpstream accepts an optional Goal because
                // a nil value signals goal deletion.
                goalUpstream <~ controller.goalCreated.map { Optional($0) }
            }
        }
    }

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        switch controller { // TODO: rework cases
        case _ where (controller as? GoalViewController) != nil:
            goalViewController = controller as! GoalViewController
        case _ where (controller as? GoalReportViewController) != nil:
            goalReportViewController = controller as! GoalReportViewController
        case _ where (controller as? NoGoalViewController) != nil:
            noGoalViewController = controller as! NoGoalViewController
        default: break
        }
    }

    private func setupContainedViewControllerVisibility() {
        displayController(goalViewController, in: goalView) // Display always

        goalDownstream.producer.filter { $0 == nil }.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            displayController(self.noGoalViewController, in: self.goalReportView)
        }

        goalDownstream.producer.filter { $0 != nil }.observe(on: UIScheduler()).startWithValues { [unowned self] _ in
            displayController(self.goalReportViewController, in: self.goalReportView)
        }
    }


    // MARK: - Outlets

    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var goalView: NSView!
    @IBOutlet weak var goalReportView: NSView!


    //  MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [GoalVCContainment, GoalReportVCContainment, NoGoalVCContainment])
        setupConnectionsWithProviders()
        setupLocalProjectDisplay()
        setupContainedViewControllerVisibility()
    }
}

class ColoredView: NSView {
    var backgroundColor: NSColor? {
        didSet {
            let cgColor: CGColor?
            if let color = backgroundColor {
                cgColor = color.cgColor
            } else {
                cgColor = nil
            }

            // TODO: learn about the right timing to apply the color without this megahack
            let delay = DispatchTime.now() + .seconds(1)
            DispatchQueue.main.asyncAfter(deadline: delay) {
                self.layer?.backgroundColor = cgColor
            }
        }
    }
}
