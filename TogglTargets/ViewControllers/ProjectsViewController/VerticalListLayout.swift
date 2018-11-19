//
//  VerticalListLayout.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

/// A vertically scrolling flow layout with a single column
class VerticalListLayout: NSCollectionViewFlowLayout {
    // Large iteritem spacing to prevent laying out more than one item on the same row.
    static let safeMinimumInteritemSpacing = CGFloat(1000)

    /// Sets the height for all items.
    var itemHeight: CGFloat {
        get {
            return itemSize.height
        }
        set {
            // Only the height matters, width is ignored as the item width will match the available width.
            itemSize = NSSize(width: 50, height: newValue)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.minimumInteritemSpacing = VerticalListLayout.safeMinimumInteritemSpacing
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        return tweak(super.layoutAttributesForElements(in: rect))
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        return tweak(super.layoutAttributesForItem(at: indexPath))
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: NSCollectionView.SupplementaryElementKind,
                                                       at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        return tweak(super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath))
    }

    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath)
        -> NSCollectionViewLayoutAttributes? {
            return tweak(super.initialLayoutAttributesForAppearingItem(at: itemIndexPath))
    }

    override func initialLayoutAttributesForAppearingSupplementaryElement(
        ofKind elementKind: NSCollectionView.SupplementaryElementKind,
        at elementIndexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        return tweak(
            super.initialLayoutAttributesForAppearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath))
    }

    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath)
        -> NSCollectionViewLayoutAttributes? {
            return tweak(super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath))
    }

    override func finalLayoutAttributesForDisappearingSupplementaryElement(
        ofKind elementKind: NSCollectionView.SupplementaryElementKind, at elementIndexPath: IndexPath)
        -> NSCollectionViewLayoutAttributes? {
            return tweak(super.finalLayoutAttributesForDisappearingSupplementaryElement(ofKind: elementKind,
                                                                                        at: elementIndexPath))
    }

    private func tweak(_ layoutAttributes: NSCollectionViewLayoutAttributes?) -> NSCollectionViewLayoutAttributes? {
        guard let original = layoutAttributes else {
            return nil
        }
        // swiftlint:disable:next force_cast
        let copied = original.copy() as! NSCollectionViewLayoutAttributes
        copied.frame.origin.x = sectionInset.left

        if let collectionView = collectionView {
            copied.frame.size.width = collectionView.bounds.width - sectionInset.left - sectionInset.right
        }

        return copied
    }

    private func tweak(_ base: [NSCollectionViewLayoutAttributes]) -> [NSCollectionViewLayoutAttributes] {
        var modified = [NSCollectionViewLayoutAttributes]()
        for attributes in base {
            guard let tweaked = tweak(attributes) else {
                continue
            }
            modified.append(tweaked)
        }
        return modified
    }
}
