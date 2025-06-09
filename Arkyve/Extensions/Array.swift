//
//  Array.swift
//  Arkyve
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

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}
