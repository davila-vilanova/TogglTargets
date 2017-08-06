//
//  NSViewControllerExtensions.swift
//  TogglGoals
//
//  Created by David Dávila on 06.08.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

extension NSViewController {
    func onViewLoaded(_ work: @escaping () -> Void) {
        let logPerformance = false
        var cnt = 0
        func cycle() {
            if (self.isViewLoaded) {
                work()
                if logPerformance {
                    print ("onViewLoaded performed work after \(cnt) delay\(cnt == 1 ? "" : "s")")
                    // Takes typically 1 cycle the first time, 0 the remaining times
                }
            } else {
                cnt += 1
                DispatchQueue.main.async {
                    cycle()
                }
            }
        }
        cycle()
    }
}

