//
//  String.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import Foundation

extension String {
    func countOccurrences(of char: Character) -> Int {
        self.ranges(of: String(char)).count
    }

    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }

    var deletingPathExtension: String {
        return (self as NSString).deletingPathExtension
    }

    var pathExtension: String {
        return (self as NSString).pathExtension
    }

    /// Checks if the string ends with a space followed by an integer.
    /// If found, the integer is incremented in-place.
    ///
    /// - Returns: `true` if a trailing integer was found and incremented,
    ///            `false` otherwise.
    @discardableResult
    mutating func incrementTrailingInteger() -> Bool {
        // Regex to find a space followed by one or more digits at the end of the string.
        // - \s: matches a single whitespace character.
        // - (\d+): matches one or more digits and captures them (the parentheses).
        // - $: anchors the match to the end of the string.
        let pattern = "\\s(\\d+)$"

        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsRange = NSRange(self.startIndex..., in: self)

            // Find the first (and in this case, only possible) match.
            guard let match = regex.firstMatch(in: self, options: [], range: nsRange) else {
                return false // No match found
            }

            // The first capture group (index 1) contains the digits.
            // The full match (index 0) contains " <digits>".
            guard match.numberOfRanges == 2 else {
                // Should not happen with this regex if a match is found
                return false
            }

            // Extract the range of the digits
            let numberNSRange = match.range(at: 1)
            guard let numberSwiftRange = Range(numberNSRange, in: self) else {
                return false // Could not convert NSRange to Swift Range
            }
            let numberString = String(self[numberSwiftRange])

            // Convert the extracted digits to an Integer
            guard let number = Int(numberString) else {
                return false // Extracted string is not a valid integer (e.g., too large)
            }

            // Increment the number
            let incrementedNumber = number + 1

            // Get the part of the string before the " <integer>"
            // The location of the full match (range at 0) is where " <integer>" starts.
            let prefixEndIndex = self.index(self.startIndex, offsetBy: match.range(at: 0).location)
            let prefix = String(self[..<prefixEndIndex])

            // Reconstruct the string
            self = "\(prefix) \(incrementedNumber)"
            return true

        } catch {
            // This would happen if the regex pattern itself is invalid,
            // which shouldn't be the case for the hardcoded pattern.
            print("Error creating regular expression: \(error)")
            return false
        }
    }
}
