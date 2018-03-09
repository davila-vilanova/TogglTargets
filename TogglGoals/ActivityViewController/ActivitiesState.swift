//
//  ActivitiesState.swift
//  TogglGoals
//
//  Created by David Dávila on 14.02.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

fileprivate typealias StateTransformation = [ActivityStatus]
fileprivate typealias StateTransformer = ([ActivityStatus]) -> StateTransformation?
fileprivate typealias CollapsePreventer = ([ActivityStatus], [ActivityStatus]) -> Bool

fileprivate let IdleProcessingDelay = TimeInterval(2.0)
fileprivate let ThrottleDelay = TimeInterval(0.5)

class ActivitiesState {
    // MARK: - State
    private let state = MutableProperty([ActivityStatus]())

    // MARK: - Input
    lazy var input = BindingTarget<ActivityStatus>(on: scheduler, lifetime: lifetime) { [unowned self] in
        self.processInput($0)
    }

    // MARK: - Output
    lazy var output: Signal<([ActivityStatus]), NoError> =
        state.signal.throttle(ThrottleDelay, on: scheduler)

    // MARK: - Infrastucture
    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()
    private let inputReceivedPipe = Signal<Void, NoError>.pipe()

    // MARK: - Transforming state
    private let onCollectStateTransformers: [StateTransformer] = []
    private let idleDelayedStateTransformers: [StateTransformer] = [cleanUpSuccessful]

    private func processInput(_ status: ActivityStatus) {
        inputReceivedPipe.input.send(value: ())
        let collected = collect(status, state.value)
        let furtherTransformed = apply(stateTransformers: onCollectStateTransformers, initialState: collected)
        process(transformation: furtherTransformed ?? collected)
    }

    private func applyIdleDelayedProcessors() {
        process(transformation: apply(stateTransformers: idleDelayedStateTransformers, initialState: state.value))
    }

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
        self.lifetime += idleDelayTarget <~ inputReceivedPipe.output.debounce(IdleProcessingDelay, on: scheduler)
    }
}

fileprivate func apply(stateTransformers: [StateTransformer], initialState: [ActivityStatus]) -> StateTransformation? {
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

fileprivate func collect(_ status: ActivityStatus, _ state: [ActivityStatus]) -> StateTransformation {
    var updatedState = state
    if let index = state.index(where: { $0.activity == status.activity }) {
        updatedState[index] = status
    } else {
        let index = updatedState.endIndex
        updatedState.insert(status, at: index)
    }
    return updatedState
}

fileprivate func cleanUpSuccessful(state: [ActivityStatus]) -> StateTransformation? {
    func anythingToCleanUp() -> Bool {
        return state.contains(where: { $0.isSuccessful })
    }

    guard anythingToCleanUp() else {
        return nil
    }

    return state.filter({ !$0.isSuccessful })
}
