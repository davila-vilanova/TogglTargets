//
//  NSViewControllerExtensions.swift
//  TogglGoals
//
//  Created by David Dávila on 25.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveCocoa

extension NSViewController {
    func doAfterViewIsLoaded(_ closure: @escaping () -> Void) {
        self.reactive.producer(forKeyPath: "isViewLoaded")
            .map { $0 as? Bool }.skipNil() // pass through only expected Bool values
            .filter { $0 } // pass through only 'true' values
            .take(first: 1) // only interested in first 'true'
            .startWithValues { _ in closure() }
    }
}
