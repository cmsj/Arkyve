//
//  ArchiveLogEntry.swift
//  ZipZap
//
//  Created by Chris Jones on 03/06/2024.
//

import Foundation

enum ArchiveLogEntryType {
    case info
    case warn
    case error
    case debug
}

struct ArchiveLogEntry: Identifiable {
    let id = UUID()
    let type: ArchiveLogEntryType
    let msg: String

    static func info(_ msg: String) -> ArchiveLogEntry {
        return Self.init(type: .info, msg: msg)
    }

    static func warn(_ msg: String) -> ArchiveLogEntry {
        return Self.init(type: .warn, msg: msg)
    }

    static func error(_ msg: String) -> ArchiveLogEntry {
        return Self.init(type: .error, msg: msg)
    }

    static func debug(_ msg: String) -> ArchiveLogEntry {
        return Self.init(type: .debug, msg: msg)
    }
}
