//
//  ActivitiesState.swift
//  TogglTargets
//
//  Created by David Dávila on 14.02.18.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Result
import ReactiveSwift

/// The output of a state transformation.
private typealias StateTransformation = [ActivityStatus]

/// An operation that transforms a collection activity statuses into another (or the same) one.
private typealias StateTransformer = ([ActivityStatus]) -> StateTransformation?

/// The amount of time to wait since no input has been received to apply any transformations that deal with idle states.
private let idleProcessingDelay = TimeInterval(2.0)

/// The minimum period between outputs.
private let throttleDelay = TimeInterval(0.5)

/// Collects individual activity statuses and outputs processed and grouped statuses that make sense in the user
/// interface.
class ActivitiesState {

    // MARK: - Input

    lazy var input = BindingTarget<ActivityStatus>(on: scheduler, lifetime: lifetime) { [unowned self] in
        self.processInput($0)
    }

    // MARK: - Output

    /// The output reflects the internal state but it is throttle to prevent too frequent changes in the UI.
    lazy var output: Signal<([ActivityStatus]), NoError> =
        state.signal.throttle(throttleDelay, on: scheduler)

    // MARK: - Infrastucture

    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()
    private let inputReceivedPipe = Signal<Void, NoError>.pipe()

    // MARK: - Transforming state

    /// The internal state of collected statuses and backer of the output value.
    private let state = MutableProperty([ActivityStatus]())

    /// The state transformers applied upon receiving an input.
    private let onCollectStateTransformers: [StateTransformer] = []

    /// The state transformers applied after an idle period.
    private let idleDelayedStateTransformers: [StateTransformer] = [cleanUpSuccessful]

    /// Collects the input and applies the input state transformers, modifying the internal state.
    private func processInput(_ status: ActivityStatus) {
        inputReceivedPipe.input.send(value: ())
        let collected = collect(status, state.value)
        let transformed = apply(stateTransformers: onCollectStateTransformers, initialState: collected)
        process(transformation: transformed ?? collected)
    }

    /// Applies the idle state transformers to the internal state.
    private func applyIdleDelayedProcessors() {
        process(transformation: apply(stateTransformers: idleDelayedStateTransformers, initialState: state.value))
    }

    /// Applies the provided transformation, if any, to the internal state.
    ///
    /// - parameters:
    ///   - transformation: The transformation to apply to the internal state, or nil to skip.
    private func process(transformation: StateTransformation?) {
        if let newState = transformation {
            state.value = newState
        }
    }

    // MARK: - Set up

    init() {
        let idleDelayTarget = BindingTarget<Void>(on: scheduler, lifetime: lifetime) { [weak self] _ in
            self?.applyIdleDelayedProcessors()
        }
        self.lifetime += idleDelayTarget <~ inputReceivedPipe.output.debounce(idleProcessingDelay, on: scheduler)
    }
}

/// Returns the result of applying the provided transformations to a state.
///
/// - parameters:
///   - stateTransformers: The transformations to apply.
///   - initialState: The state to which to apply the provided transformations.
///
/// - returns: The result of applying the transformations, or nil if no transformations were applied.
private func apply(stateTransformers: [StateTransformer], initialState: [ActivityStatus]) -> StateTransformation? {
        var state = initialState
        var didTransform = false
        for transformer in stateTransformers {
            let transformation = transformer(state)
            if let newState = transformation {
                state = newState
            }
            didTransform = didTransform || (transformation != nil)
        }
        return didTransform ? state : nil
}

/// Collects the provided status in the provided state.
///
/// - parameters:
///   - status: The status to collect.
///   - state: The collection of statuses (internal state) in which to collect new the status.
///            If a status for the same activity is already included in the state, this operation will overwrite it.
///
/// - returns: The result of collecting the status in the state.
private func collect(_ status: ActivityStatus, _ state: [ActivityStatus]) -> StateTransformation {
    var updatedState = state
    if let index = state.index(where: { $0.activity == status.activity }) {
        updatedState[index] = status
    } else {
        let index = updatedState.endIndex
        updatedState.insert(status, at: index)
    }
    return updatedState
}

/// Returns a new state with all successful statuses removed.
///
/// - parameters:
///   - state: The internal state to clean up.
///
/// - returns: A state transformation consisting of a new state with all successful statuses removed, or nil if there
///            were no successful states to remove and as a consequence the state does not need to change.
private func cleanUpSuccessful(state: [ActivityStatus]) -> StateTransformation? {
    func anythingToCleanUp() -> Bool {
        return state.contains(where: { $0.isSuccessful })
    }

    guard anythingToCleanUp() else {
        return nil
    }

    return state.filter({ !$0.isSuccessful })
}
