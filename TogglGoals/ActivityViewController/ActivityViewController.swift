//
//  ActivityViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 28.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

fileprivate let CondensedActivityVCContainment = "CondensedActivityVCContainment"
fileprivate let CollectionViewExpandedSize: CGFloat = 80

class ActivityViewController: NSViewController, ViewControllerContaining {
    internal func connectInputs(modelRetrievalStatus source: SignalProducer<ActivityStatus, NoError>) {
        enforceOnce(for: "ActivityViewController.connectInterface()") { [unowned self] in
            self.activitiesState.input <~ source
        }
    }

    internal lazy var wantsDisplay = Property<Bool>(initial: false, then: activityStatuses.producer.map { !$0.isEmpty })
    private var wantsExtendedDisplay = MutableProperty(false)

    private let (lifetime, token) = Lifetime.make()
    private let activitiesState = ActivitiesState()
    private lazy var activityStatuses = Property(initial: [ActivityStatus](), then: activitiesState.output)

    @IBOutlet weak var condensedActivityView: NSView!
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var collectionViewHeight: NSLayoutConstraint!

    var condensedActivityViewController: CondensedActivityViewController!

    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?) {
        if let condensedActivityViewController = controller as? CondensedActivityViewController {
            self.condensedActivityViewController = condensedActivityViewController
            displayController(condensedActivityViewController, in: condensedActivityView)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeControllerContainment(containmentIdentifiers: [CondensedActivityVCContainment])

        configureCollectionView()

        collectionView.reactive.makeBindingTarget(on: UIScheduler()) { $0.content = $1 as [ActivityStatus] }
            <~ self.activityStatuses.producer

        condensedActivityViewController.connectInterface(
            activityStatuses: activityStatuses.producer,
            expandDetails: wantsExtendedDisplay.bindingTarget)

        collectionView.reactive.makeBindingTarget(on: UIScheduler()) {
            $0.animator().isHidden = $1
            } <~ wantsExtendedDisplay.negate()

        collectionViewHeight.reactive.makeBindingTarget(on: UIScheduler()) {
            $0.animator().constant = $1
            } <~ wantsExtendedDisplay.map { $0 ? CollectionViewExpandedSize : 0 }
    }

    private func configureCollectionView() {
        (collectionView.collectionViewLayout as! NSCollectionViewGridLayout).maximumNumberOfColumns = 1
        collectionView.register(ActivityCollectionViewItem.self,
                                forItemWithIdentifier: NSUserInterfaceItemIdentifier("ActivityCollectionViewItem"))
    }

}

private extension Array where Element == ActivityStatus {
    var hasExecutingActivities: Bool {
        return self.filter { $0.isExecuting }.count > 0
    }
    var hasErrors: Bool {
        return self.filter { $0.isError }.count > 0
    }
}
