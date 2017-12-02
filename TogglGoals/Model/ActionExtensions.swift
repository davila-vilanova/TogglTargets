//
//  ActionExtensions.swift
//  TogglGoals
//
//  Created by David Dávila on 02.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

extension Action {
    func applySerially(_ input: Input) -> SignalProducer<Output, Error> {
        return self.isEnabled.producer.filter { $0 }
            .take(first: 1)
            .map { _ in self.apply(input) }.flatten(.latest)
            .mapError {
                switch $0 {
                case .disabled:
                    fatalError()
                case .producerFailed(let producerError):
                    return producerError
                }
        }
    }

    var serialInput: BindingTarget<Input> {
        return BindingTarget(lifetime: lifetime) { [weak self] in self?.applySerially($0).start() }
    }
}
