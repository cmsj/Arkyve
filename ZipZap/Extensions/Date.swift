//
//  Date.swift
//  ZipZap
//
//  Created by Chris Jones on 29/05/2024.
//

import Foundation

/// An extension on `Date` that provides formatting and initialization utilities.
extension Date {
    /// Returns a user-friendly formatted string representation of the date.
    ///
    /// The date is formatted as "d MMM yyyy 'at' HH:mm" (e.g., "29 May 2024 at 14:30").
    /// If the date is January 1, 1970 (timeIntervalSince1970: 0), returns "--" instead.
    ///
    /// - Returns: A formatted string representation of the date.
    var userFormatted: String {
        get {
            if self == Date(timeIntervalSince1970: 0) { return "--" }
            let formatter = DateFormatter()

            formatter.dateFormat = "d MMM yyyy 'at' HH:mm"
            return formatter.string(from: self)
        }
    }

    /// Creates a new Date instance from a Unix timestamp.
    ///
    /// - Parameter since: A Unix timestamp (seconds since January 1, 1970).
    public init(since: time_t) {
        self.init(timeIntervalSince1970: TimeInterval(since))
    }
}
