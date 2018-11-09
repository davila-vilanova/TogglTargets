//
//  WeekdaySelection+Value.swift
//  TogglTargets
//
//  Created by David Dávila on 09.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import SQLite

extension WeekdaySelection: Value {
    typealias Datatype = Int64

    static var declaredDatatype: String {
        return Int64.declaredDatatype
    }

    static func fromDatatypeValue(_ datatypeValue: Datatype) -> WeekdaySelection {
        return WeekdaySelection(integerRepresentation: IntegerRepresentationType(datatypeValue))
    }

    var datatypeValue: Datatype {
        return Datatype(integerRepresentation)
    }
}
