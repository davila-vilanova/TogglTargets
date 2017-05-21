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
    
    var itemSize = CGSize(width: 150, height: 80)
    var itemMargin = EdgeInsets(top: -4, left: -2, bottom: -4, right: -2)
    var headerSize = CGSize(width: 150, height: 25)
    var headerMargin = EdgeInsets(top: -8, left: -2, bottom: -4, right: -2)
    
    var contentSize = NSZeroSize
    
    override func prepare() {
        guard let collectionView = collectionView else {
            return
        }
        
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
        
        func widthWithMargin(size: CGSize, margin: EdgeInsets) -> CGFloat {
            return size.width - margin.left - margin.right
        }
        let fullItemWidth = widthWithMargin(size: itemSize, margin: itemMargin)
        let fullHeaderWidth = widthWithMargin(size: headerSize, margin: headerMargin)
        
        contentSize = CGSize(width: max(fullItemWidth, fullHeaderWidth), height: yPos)
    }

    override func prepare(forCollectionViewUpdates updateItems: [NSCollectionViewUpdateItem]) {
        for updateItem in updateItems {
            switch updateItem.updateAction {
            case .insert:
                accountForInsertion(at: updateItem.indexPathAfterUpdate!)
            case .delete:
                accountForDeletion(at: updateItem.indexPathBeforeUpdate!)
            case .move:
                accountForMove(from: updateItem.indexPathBeforeUpdate!, to: updateItem.indexPathAfterUpdate!)
            case .reload:
                continue
            case .none:
                continue
            }
        }
    }

    private func accountForInsertion(at indexPath: IndexPath) {
        offsetRects(from: indexPath, by: 1)
    }

    private func accountForDeletion(at indexPath: IndexPath) {
        offsetRects(from: indexPath, by: -1)
    }

    private func accountForMove(from: IndexPath, to: IndexPath) {

    }

    private func offsetRects(from indexPath: IndexPath, by count: Int) {

    }

    override var collectionViewContentSize: NSSize {
        return contentSize
    }
    
    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        var allAttributes = [NSCollectionViewLayoutAttributes]()
        
        for (indexPath, headerRect) in headerRects {
            if headerRect.intersects(rect) {
                let attributes = NSCollectionViewLayoutAttributes(forSupplementaryViewOfKind: NSCollectionElementKindSectionHeader, with: indexPath)
                attributes.frame = headerRect
                allAttributes.append(attributes)
            }
        }
        
        for (indexPath, itemRect) in itemRects {
            if itemRect.intersects(rect) {
                let attributes = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
                attributes.frame = itemRect
                allAttributes.append(attributes)
            }
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
    
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard elementKind == NSCollectionElementKindSectionHeader else {
            return nil
        }
        guard let headerRect = headerRects[indexPath] else {
            return nil
        }
        let attributes = NSCollectionViewLayoutAttributes(forSupplementaryViewOfKind: NSCollectionElementKindSectionHeader, with: indexPath)
        attributes.frame = headerRect
        return attributes
    }
}
