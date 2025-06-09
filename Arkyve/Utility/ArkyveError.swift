//
//  ArkyveError.swift
//  Arkyve
//
//  Created by Chris Jones on 23/12/2024.
//

import Foundation

struct ArkyveError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    enum ErrorKind: String {
        case newArchive = "New"
        case openArchive = "Open"
        case readArchive = "Read"
        case writeArchive = "Write"
        case addFiles = "Add Files"
        case extract = "Extract"
        case quicklook = "Quicklook"
        case drop = "Drop"
        case entries = "Entries"
        case cancelled = "Cancelled"
        case rename = "Rename"
        case urlCache = "URL Cache"
        case scopedURLRefresh = "URL Bookmark Refresh"
        case unknown = "Unknown"
    }

    let kind: ErrorKind
    let msg: String

    var description: String {
        localizedDescription
    }

    var localizedDescription: String {
        "\(kind.rawValue): \(msg)"
    }

    var localizedStringResource: LocalizedStringResource {
        "\(kind.rawValue): \(msg)"
    }

    init(_ kind: ErrorKind, msg: String) {
        self.kind = kind

        if kind == .cancelled && msg == "" {
            self.msg = "User cancelled operation."
        } else {
            self.msg = msg
        }
    }
}
