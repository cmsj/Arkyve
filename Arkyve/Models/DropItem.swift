//
//  DropItem.swift
//  Arkyve
//
//  Created by Chris Jones on 01/03/2025.
//
import SwiftUI

enum DropItem: Codable, Transferable {
    case none
    case file(URL)
    case entry(ArchiveEntryExtractable)
    // FIXME: Until we figure out how to support dragging image types without clobbering URLs, this can't be here
//    case image(Data)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { DropItem.entry($0) }
        ProxyRepresentation { DropItem.file($0) }
//        ProxyRepresentation { DropItem.image($0) }
    }

    var file: URL? {
        switch self {
        case .file(let url): return url
        default: return nil
        }
    }

    var entry: ArchiveEntryExtractable? {
        switch self {
        case .entry(let entry): return entry
        default: return nil
        }
    }

//    var image: Data? {
//        switch self {
//        case .image(let nsImage): return nsImage
//        default: return nil
//        }
//    }
}
