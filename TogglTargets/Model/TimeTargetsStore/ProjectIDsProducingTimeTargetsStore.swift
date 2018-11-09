//
//  ProjectIDsProducingTimeTargetsStore.swift
//  TogglTargets
//
//  Created by David Dávila on 09.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

/// Represents an entity that conforms to both the `TimeTargetsStore` and `ProjectIDsByTimeTargetsProducing` protocols.
protocol ProjectIDsProducingTimeTargetsStore: TimeTargetsStore, ProjectIDsByTimeTargetsProducing { }
