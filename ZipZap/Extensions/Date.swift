//
//  Date.swift
//  ZipZap
//
//  Created by Chris Jones on 29/05/2024.
//

import Foundation

extension Date {
    // Return in the format we need for UI table columns
    var userFormatted: String {
        get {
            if self == Date(timeIntervalSince1970: 0) { return "--" }
            let formatter = DateFormatter()
            // TODO: Somehow hook up the styles to some user settings
            formatter.dateStyle = .long
            formatter.timeStyle = .long
            return formatter.string(from: self)
        }
    }

    public init(since: time_t) {
        self.init(timeIntervalSince1970: TimeInterval(since))
    }
}
