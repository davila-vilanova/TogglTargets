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

    internal var projects: BindingTarget<[Int64 : Project]> { return _projects.deoptionalizedBindingTarget }
    internal var goals: BindingTarget<[Int64 : Goal]> { return _goals.deoptionalizedBindingTarget }
    internal var runningEntry: BindingTarget<RunningEntry?> { return _runningEntry.bindingTarget }
    internal var now: BindingTarget<Date> { return _now.deoptionalizedBindingTarget }

    internal lazy var selectedProject = Property<Project?>(_selectedProject)


    // MARK: - Backing properties

    private let _projects = MutableProperty<[Int64 : Project]?>(nil)
    private let _goals = MutableProperty<[Int64 : Goal]?>(nil)
    private let _runningEntry = MutableProperty<RunningEntry?>(nil)
    private let _now = MutableProperty<Date?>(nil)
    private let _selectedProject = MutableProperty<Project?>(nil)


    // MARK: - Project, goal and report providing

    // TODO: Generalize and encapsulate?
    internal var goalReadProviderProducer: SignalProducer<PropertyProvidingAction<Goal>, NoError>! {
        didSet {
            assert(goalReadProviderProducer != nil)
            assert(oldValue == nil)
            if let producer = goalReadProviderProducer {
                goalReadProvider <~ producer.take(first: 1)
            }
        }
    }
    private let goalReadProvider = MutableProperty<PropertyProvidingAction<Goal>?>(nil)

    internal var reportReadProviderProducer: SignalProducer<PropertyProvidingAction<TwoPartTimeReport>, NoError>! {
        didSet {
            assert(reportReadProviderProducer != nil)
            assert(oldValue == nil)
            if let producer = reportReadProviderProducer {
                reportReadProvider <~ producer.take(first: 1)
            }
        }
    }
    private let reportReadProvider = MutableProperty<PropertyProvidingAction<TwoPartTimeReport>?>(nil)


    // MARK: Preparing collection view data

    enum Section: Int {
        case withGoal = 0
        case withoutGoal = 1

        static var count = 2
    }

    private struct CollectionViewMetadata {
        private let projectIdsToIndexPaths: [Int64 : IndexPath]
        private let indexPathsToProjectIds: [IndexPath : Int64]
        let countOfProjectsWithGoals: Int
        let countOfProjectsWithoutGoals: Int
        let projectIdsWithChangedGoals: [Int64]

        init(projects: [Int64 : Project], goals: [Int64 : Goal], previousGoals: [Int64 : Goal]?) {
            let changesInGoals = goals.keysOfDifferingValues(with: previousGoals)
            let sortedIds: [Int64] = [Int64](projects.keys).sorted(by: { (idA, idB) -> Bool in
                let goalA = goals[idA]
                let goalB = goals[idB]

                if goalA != nil, goalB == nil {
                    // a goal is more goaler than a no goal
                    return true
                } else if let a = goalA, let b = goalB {
                    // the larger goal comes first
                    return a > b
                } else {
                    return false
                }
            })
            let idsOfProjectsWithGoals: ArraySlice<Int64> = sortedIds.prefix { (projectId) -> Bool in
                return goals[projectId] != nil
            }
            let idsOfProjectsWithoutGoals = sortedIds.suffix(from: idsOfProjectsWithGoals.count)

            var idsToIndexPaths = [Int64 : IndexPath]()
            var indexPathsToIds = [IndexPath : Int64]()
            for (index, projectId) in idsOfProjectsWithGoals.enumerated() {
                let indexPath = IndexPath(item: index, section: Section.withGoal.rawValue)
                idsToIndexPaths[projectId] = indexPath
                indexPathsToIds[indexPath] = projectId
            }
            for (index, projectId) in idsOfProjectsWithoutGoals.enumerated() {
                let indexPath = IndexPath(item: index, section: Section.withoutGoal.rawValue)
                idsToIndexPaths[projectId] = indexPath
                indexPathsToIds[indexPath] = projectId
            }

            projectIdsToIndexPaths = idsToIndexPaths
            indexPathsToProjectIds = indexPathsToIds
            countOfProjectsWithGoals = idsOfProjectsWithGoals.count
            countOfProjectsWithoutGoals = idsOfProjectsWithoutGoals.count
            self.projectIdsWithChangedGoals = changesInGoals
        }

        func indexPath(for projectId: Int64) -> IndexPath? {
            return projectIdsToIndexPaths[projectId]
        }

        func projectId(for indexPath: IndexPath) -> Int64? {
            return indexPathsToProjectIds[indexPath]
        }
    }

    private lazy var metadata: MutableProperty<CollectionViewMetadata?> = {
        let p = MutableProperty<CollectionViewMetadata?>(nil)

        p <~ SignalProducer.combineLatest(_projects.producer.skipNil(), _goals.producer.combinePrevious())
            .map { (input) -> CollectionViewMetadata? in
                let (projects, (previousGoals, currentGoals)) = input
                guard let goals = currentGoals else {
                    return nil
                }
                return CollectionViewMetadata(projects: projects, goals: goals, previousGoals: previousGoals)
        }

        return p
    }()

    private let (lifetime, token) = Lifetime.make()

    private lazy var reloadList = BindingTarget<()>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (_) in
        self.projectsCollectionView.reloadData()
        self.updateSelection()
        self.scrollToSelection()
    }

    private lazy var updateList =
        BindingTarget<(CollectionViewMetadata, CollectionViewMetadata)>(on: UIScheduler(), lifetime: lifetime) { [unowned self] (previousMetadata, currentMetadata) in
            for projectId in currentMetadata.projectIdsWithChangedGoals {
                let oldIndexPath = previousMetadata.indexPath(for: projectId)!
                let newIndexPath = currentMetadata.indexPath(for: projectId)!
                guard oldIndexPath != newIndexPath else {
                    continue
                }
                self.projectsCollectionView.animator().moveItem(at: oldIndexPath, to: newIndexPath)
            }
    }

    // MARK: - Outlets

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

        reloadList <~ metadata.producer.skipNil().filter { $0.projectIdsWithChangedGoals.count == 0 }.map { _ in return () }

        updateList <~ metadata.producer.skipNil().combinePrevious().filter { (_, currentMetadata) in currentMetadata.projectIdsWithChangedGoals.count > 0 }
    }

    private func updateSelection() {
        _selectedProject.value = {
            guard let indexPath = projectsCollectionView.selectionIndexPaths.first else {
                return nil
            }
            guard let projectId = metadata.value?.projectId(for: indexPath) else {
                return nil
            }
            return _projects.value?[projectId]
        }()
    }

    private func scrollToSelection() {
        assert(Thread.current.isMainThread)
        projectsCollectionView.animator().scrollToItems(at: projectsCollectionView.selectionIndexPaths, scrollPosition: .nearestHorizontalEdge)
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return Section.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .withGoal: return metadata.value?.countOfProjectsWithGoals ?? 0
        case .withoutGoal: return metadata.value?.countOfProjectsWithoutGoals ?? 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ProjectItemIdentifier, for: indexPath)
        let projectItem = item as! ProjectCollectionViewItem
        projectItem.connectOnceInLifecycle(runningEntry: _runningEntry.producer, now: _now.producer.skipNil())

        let projectId = metadata.value!.projectId(for: indexPath)!

        let projectProperty: Property<Project?> = _projects.map { $0?[projectId] }
        projectItem.projects <~ SignalProducer<Property<Project?>, NoError>(value: projectProperty)
        projectItem.goals <~ goalReadProvider.value!.apply(projectId).mapToNoError()
        projectItem.reports <~ reportReadProvider.value!.apply(projectId).mapToNoError()

        return projectItem
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.SupplementaryElementKind.sectionHeader, withIdentifier: SectionHeaderIdentifier, for: indexPath)
        if let header = view as? ProjectCollectionViewHeader {
            switch Section(rawValue: indexPath.section)! {
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

// MARK: -

fileprivate extension Dictionary where Value: Equatable {
    func keysOfDifferingValues(with anotherDictionaryOrNil: Dictionary<Key, Value>?) -> [Key] {
        var diffKeys = [Key]()

        guard let otherness = anotherDictionaryOrNil else {
            return diffKeys
        }

        let allKeys = Set<Key>(self.keys).union(otherness.keys)
        for key in allKeys {
            if self[key] != otherness[key] {
                diffKeys.append(key)
            }
        }
        return diffKeys
    }
}


// MARK: -

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

