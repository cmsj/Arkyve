//
//  ArkyveProgressState.swift
//  Arkyve
//
//  Created by Chris Jones on 02/05/2025.
//


enum ArkyveProgressState: Equatable, CustomStringConvertible {
    case idle
    case indeterminate
    case determinate(Double)

    var value: Double {
        switch self {
        case .idle, .indeterminate:
            return 0.0
        case .determinate(let value):
            return value
        }
    }

    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .indeterminate:
            return "Working..."
        case .determinate(let value):
            return "\(Int(value * 100))%"
        }
    }
}
