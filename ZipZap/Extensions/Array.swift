//
//  Array.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import Foundation

extension Array {
    /// Filters an array into two arrays based on a predicate.
    ///
    /// This function splits the array into two parts:
    /// - Elements that satisfy the predicate
    /// - Elements that don't satisfy the predicate
    ///
    /// - Parameter isIncluded: A closure that takes an element and returns a Boolean value indicating whether the element should be included in the first array.
    /// - Returns: A tuple containing two arrays: the first array contains elements that satisfy the predicate, and the second array contains elements that don't.
    /// - Throws: An error if the predicate throws an error.
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

    /// Removes elements from the array that satisfy the given predicate.
    ///
    /// This function removes all elements that satisfy the given predicate and returns a Boolean indicating whether any elements were removed.
    ///
    /// - Parameter test: A closure that takes an element and returns a Boolean value indicating whether the element should be removed.
    /// - Returns: `true` if any elements were removed, `false` otherwise.
    @discardableResult
    mutating func remove(where test: (Self.Element) -> Bool) -> Bool {
        let beforeCount = self.count
        self = self.filter { !test($0) }

        return beforeCount != self.count
    }
}

extension Array where Element == String {
    /// Subtracts a path prefix from an array of strings.
    ///
    /// This function checks if the array starts with the given path and returns the remaining elements after the path.
    ///
    /// - Parameter path: An array of strings representing the path to subtract.
    /// - Returns: An array of strings containing the elements after the path, or `nil` if the array doesn't start with the given path.
    func subtractPath(_ path: [String]) -> [String]? {
        guard self.count >= path.count else {
            print("Array::subtractPath called with a path that is longer (\(path.count)) than I am (\(self.count).")
            return nil
        }

        guard self.prefix(path.count).elementsEqual(path) else {
            print("Array::subtractPath does not start with the path provided.")
            return nil
        }

        return Array(self.suffix(from: path.count))
    }
}
