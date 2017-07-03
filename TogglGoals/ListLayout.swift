//
//  ListLayout.swift
//  TogglGoals
//
//  Created by David Dávila on 18.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

class ListLayout: NSCollectionViewLayout {
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
