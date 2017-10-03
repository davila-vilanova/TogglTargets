//
//  ProjectsListViewController.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

fileprivate let ProjectItemIdentifier = NSUserInterfaceItemIdentifier("ProjectItemIdentifier")
fileprivate let SectionHeaderIdentifier = NSUserInterfaceItemIdentifier("SectionHeaderIdentifier")


class ProjectsListViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate {

    // MARK: - Exposed targets and source

    internal var projectsByGoals: BindingTarget<ProjectsByGoals> { return _projectsByGoals.deoptionalizedBindingTarget }
    internal var fullProjectsUpdate: BindingTarget<Bool> { return _fullProjectsUpdate.deoptionalizedBindingTarget }
    internal var cluedProjectsUpdate: BindingTarget<CollectionUpdateClue> { return _cluedProjectsUpdate.deoptionalizedBindingTarget }

    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }
    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }

    internal lazy var selectedProject = Property<Project?>(_selectedProject)


    // MARK: - Backing properties

    private let _projectsByGoals = MutableProperty<ProjectsByGoals?>(nil)
    private let _fullProjectsUpdate = MutableProperty<Bool?>(nil)
    private let _cluedProjectsUpdate = MutableProperty<CollectionUpdateClue?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _now = MutableProperty<Date?>(nil)
    private let _selectedProject = MutableProperty<Project?>(nil)


    // MARK: - Goal and report providing

    // TODO: Generalize and encapsulate?
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


    // MARK: Outlets

    @IBOutlet weak var projectsCollectionView: NSCollectionView!


    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()

        projectsCollectionView.dataSource = self
        projectsCollectionView.delegate = self

        let itemNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewItem"), bundle: nil)!
        projectsCollectionView.register(itemNib, forItemWithIdentifier: ProjectItemIdentifier)

        let headerNib = NSNib(nibNamed: NSNib.Name(rawValue: "ProjectCollectionViewHeader"), bundle: nil)!
        projectsCollectionView.register(headerNib, forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: SectionHeaderIdentifier)

        let providersProducer = SignalProducer.combineLatest(goalReadProvider.producer.skipNil().take(first: 1),
                                                             reportReadProvider.producer.skipNil().take(first: 1))
        providersProducer.combineLatest(with: _fullProjectsUpdate.producer.skipNil().filter { $0 })
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] (_) in
                self.reloadList()
        }
        providersProducer.combineLatest(with: _cluedProjectsUpdate.producer.skipNil())
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] (_, clue) in
                self.updateList(with: clue)
        }
    }

    private func reloadList() {
        projectsCollectionView.reloadData()
        updateSelection()
        scrollToSelection()
    }

    private func updateList(with clue: CollectionUpdateClue) {
        // First move items that have moved, then delete items at old index paths, finally add items at new index paths
        if let moved = clue.movedItems {
            for (oldIndexPath, newIndexPath) in moved {
                projectsCollectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
            }
        }
        if let removed = clue.removedItems {
            projectsCollectionView.animator().deleteItems(at: removed)
        }
        if let added = clue.addedItems {
            projectsCollectionView.animator().insertItems(at: added)
        }

        scrollToSelection()
    }

    private func updateSelection() {
        let indexPath = projectsCollectionView.selectionIndexPaths.first
        _selectedProject.value = _projectsByGoals.value?.project(for: indexPath)
    }

    private func scrollToSelection() {
        assert(Thread.current.isMainThread)
        projectsCollectionView.animator().scrollToItems(at: projectsCollectionView.selectionIndexPaths, scrollPosition: .nearestHorizontalEdge)
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return ProjectsByGoals.Section.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let projectsByGoalsValue = _projectsByGoals.value

        switch ProjectsByGoals.Section(rawValue: section)! {
        case .withGoal: return projectsByGoalsValue?.idsOfProjectsWithGoals.count ?? 0
        case .withoutGoal: return projectsByGoalsValue?.idsOfProjectsWithoutGoals.count ?? 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ProjectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem
        projectItem.connectOnceInLifecycle(runningEntry: _runningEntry.producer, now: _now.producer.skipNil())

        // TODO: what would happen if the value of projectsByGoals changed while the CollectionView is updating its contents?
        let project = _projectsByGoals.value!.project(for: indexPath)!
        projectItem.currentProject = project
        projectItem.goals <~ goalReadProvider.value!.apply(project.id).mapToNoError()
        projectItem.reports <~ reportReadProvider.value!.apply(project.id).mapToNoError()

        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: SectionHeaderIdentifier, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            switch ProjectsByGoals.Section(rawValue: indexPath.section)! {
            case .withGoal: header.title = "projects with goals"
            case .withoutGoal: header.title = "projects without goals"
            }

        }
        return view
    }


    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateSelection()
    }
}

internal class ListLayout: NSCollectionViewLayout {
    private var itemRects = Dictionary<IndexPath, CGRect>()
    private var headerRects = Dictionary<IndexPath, CGRect>()

    var contentSize = NSZeroSize

    override func prepare() {
        guard let collectionView = collectionView else {
            return
        }

        let width = collectionView.bounds.size.width
        let itemSize = CGSize(width: width, height: 80)
        let itemMargin = NSEdgeInsets(top: -4, left: -2, bottom: -4, right: -2)
        let headerSize = CGSize(width: width, height: 25)
        let headerMargin = NSEdgeInsets(top: -8, left: -2, bottom: -4, right: -2)

        itemRects.removeAll()
        headerRects.removeAll()

        let numberOfSections = collectionView.numberOfSections
        var yPos = CGFloat(0.0)
        for section in 0..<numberOfSections {
            let headerOrigin = CGPoint(x: (0 - headerMargin.left),
                                       y: yPos + (0 - headerMargin.top))
            let indexPath = IndexPath(item: 0, section: section)
            headerRects[indexPath] = CGRect(origin: headerOrigin, size: headerSize)

            yPos = headerOrigin.y + headerSize.height + (0 - headerMargin.bottom)

            let itemsInSection = collectionView.numberOfItems(inSection: section)
            for item in 0..<itemsInSection {
                let itemOrigin = CGPoint(x: (0 - itemMargin.left),
                                         y: yPos + (0 - itemMargin.top))
                let indexPath = IndexPath(item: item, section: section)
                itemRects[indexPath] = CGRect(origin: itemOrigin, size: itemSize)

                yPos = itemOrigin.y + itemSize.height + (0 - itemMargin.bottom)
            }
        }

        func widthWithMargin(size: CGSize, margin: NSEdgeInsets) -> CGFloat {
            return size.width - margin.left - margin.right
        }
        let fullItemWidth = widthWithMargin(size: itemSize, margin: itemMargin)
        let fullHeaderWidth = widthWithMargin(size: headerSize, margin: headerMargin)

        contentSize = CGSize(width: max(fullItemWidth, fullHeaderWidth), height: yPos)
    }

    override var collectionViewContentSize: NSSize {
        return contentSize
    }

    private func indexPathsOfItems(from dictionary: Dictionary<IndexPath, CGRect>, in rect: NSRect) -> Set<IndexPath> {
        var collected = Set<IndexPath>()
        for (indexPath, itemRect) in dictionary {
            if itemRect.intersects(rect) {
                collected.insert(indexPath)
            }
        }
        return collected
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        var allAttributes = [NSCollectionViewLayoutAttributes]()

        let headerIndexPaths = indexPathsOfItems(from: headerRects, in: rect)

        for indexPath in headerIndexPaths {
            let attributes = NSCollectionViewLayoutAttributes(forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader, with: indexPath)
            let headerRect = headerRects[indexPath]
            attributes.frame = headerRect!
            allAttributes.append(attributes)
        }

        let itemIndexPaths = indexPathsOfItems(from: itemRects, in: rect)

        for indexPath in itemIndexPaths {
            let attributes = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
            let itemRect = itemRects[indexPath]
            attributes.frame = itemRect!
            allAttributes.append(attributes)
        }

        return allAttributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard let itemRect = itemRects[indexPath] else {
            return nil
        }
        let attributes = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
        attributes.frame = itemRect
        return attributes
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard elementKind == NSCollectionView.SupplementaryElementKind.sectionHeader else {
            return nil
        }
        guard let headerRect = headerRects[indexPath] else {
            return nil
        }
        let attributes = NSCollectionViewLayoutAttributes(forSupplementaryViewOfKind: NSCollectionView.SupplementaryElementKind.sectionHeader, with: indexPath)
        attributes.frame = headerRect
        return attributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        if abs(newBounds.width - contentSize.width) > 0.1 {
            return true
        }
        return false
    }

    override func invalidationContext(forBoundsChange newBounds: NSRect) -> NSCollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)
        context.contentSizeAdjustment.width = newBounds.width - contentSize.width
        guard let collectionView = self.collectionView else {
            return context
        }
        context.invalidateItems(at: collectionView.indexPathsForVisibleItems())
        context.invalidateSupplementaryElements(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader, at: collectionView.indexPathsForVisibleSupplementaryElements(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader))
        return context
    }

    override func invalidateLayout(with context: NSCollectionViewLayoutInvalidationContext) {
        self.contentSize.width += context.contentSizeAdjustment.width
        super.invalidateLayout(with: context)
    }
}

