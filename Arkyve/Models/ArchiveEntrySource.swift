//
//  ArchiveEntrySource.swift
//  Arkyve
//
//  Created by Chris Jones on 26/12/2024.
//

import Foundation

enum ArchiveEntrySourceType: Codable, CustomStringConvertible {
    case Archive
    case Filesystem
    case InMemory
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

struct ArchiveEntrySource: Codable, CustomStringConvertible, Equatable {
    let type: ArchiveEntrySourceType
    let pathInArchive: String
    var url: URL = URL(fileURLWithPath: "/INVALID")

    var description: String {
        if type == .Filesystem {
            return "\(type): \(url)"
        }
        return "\(type): \(pathInArchive)"
    }
}
