//
//  ArchiveEntrySource.swift
//  ZipZap
//
//  Created by Chris Jones on 26/12/2024.
//

enum ArchiveEntrySourceType: Codable, CustomStringConvertible {
    case Archive
    case Filesystem
    case InMemory // FIXME: We don't have write support for these yet
    // FIXME: Dragging into InMemory folders also doesn't seem to work
    case Root
    case Synthetic

    var description: String {
        switch (self) {
        case .Archive: return "Archive"
        case .Filesystem: return "Filesystem"
        case .Root: return "Root"
        case .Synthetic: return "Synthetic"
        case .InMemory: return "In Memory"
        }
    }
}

struct ArchiveEntrySource: Codable, CustomStringConvertible {
    let type: ArchiveEntrySourceType
    let path: String

    var description: String {
        return "\(type): \(path)"
    }
}
