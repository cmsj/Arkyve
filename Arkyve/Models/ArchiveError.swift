//
//  ArchiveError.swift
//  Arkyve
//
//  Created by Chris Jones on 23/12/2024.
//

enum ArchiveError: Error {
    case ArchiveOpenError(archive: String?, error: String)
    case ArchiveWriteError(archive: String?, error: String)
    case ArchiveEntriesError(archive: String?, error: String)
    case ArchiveExtractError(archive: String?, error: String)
    case ArchiveQuicklookError(archive: String?, error: String)
    case ArchiveDropError(msg: String)
    case ArchiveUnknownError(msg: String)
}

extension ArchiveError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ArchiveOpenError(let archive, let msg):
            return String(localized: "Unable to open '\(archive ?? "UNKNOWN")': \(msg)")
        case .ArchiveWriteError(let archive, let msg):
            return String(localized: "Unable to write \(archive ?? "UNKNOWN")': \(msg)")
        case .ArchiveEntriesError(let archive, let msg):
            return String(localized: "Unable to read '\(archive ?? "UNKNOWN")': \(msg)")
        case .ArchiveExtractError(let archive, let msg):
            return String(localized: "Unable to extract '\(archive ?? "UNKNOWN")': \(msg)")
        case .ArchiveQuicklookError(let archive, let msg):
            return String(localized: "Unable to Quicklook '\(archive ?? "UNKNOWN")': \(msg)")
        case .ArchiveDropError(let msg):
            return String(localized: "Unable to drop: \(msg)")
        case .ArchiveUnknownError(let msg):
            return String(localized: "Unknown error: \(msg)")
        }
    }
}

// We need to declare conformance to Equatable so this object can be used with .onChange() in SwiftUI
extension ArchiveError: Equatable {
}
