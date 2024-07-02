//
//  Array.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import Foundation

extension Array {
    func filterBothwise(_ isIncluded: (Element) throws -> Bool) rethrows -> ([Element], [Element]) {
        var included: [Element] = []
        var excluded: [Element] = []

        for element in self {
            if try isIncluded(element) {
                included.append(element)
            } else {
                excluded.append(element)
            }
        }

        return (included, excluded)
    }

    /// Remove elements in response to a closure
    /// - Parameter test: Closure that returns true if an element should be removed
    /// - Returns: true if elements were removed, otherwise false
    @discardableResult
    mutating func remove(where test: (Self.Element) -> Bool) -> Bool {
        let beforeCount = self.count
        self = self.filter { !test($0) }

        return beforeCount != self.count
    }
}
