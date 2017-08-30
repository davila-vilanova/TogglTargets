//
//  DisposableBag.swift
//  TogglGoals
//
//  Created by David Dávila on 25.08.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

struct DisposableBag {
    private var disposables = [Disposable]()

    mutating func put(_ disposable: Disposable?) {
        if let d = disposable {
            disposables.append(d)
        }
    }

    mutating func disposeAll() {
        for d in disposables {
            d.dispose()
        }
        disposables.removeAll()
    }
}
