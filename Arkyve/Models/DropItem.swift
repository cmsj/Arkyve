//
//  DropItem.swift
//  Arkyve
//
//  Created by Chris Jones on 01/03/2025.
//
import Foundation
import SwiftUI

enum DropItem: Codable, Transferable {
    case none
    case file(URL)
    case entry(ArchiveEntryExtractable)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { DropItem.entry($0) }
        ProxyRepresentation { DropItem.file($0) }
        FileRepresentation(importedContentType: .image) { url in
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(url.file.lastPathComponent)
            try FileManager.default.copyItem(at: url.file, to: tempURL)
            return DropItem.file(tempURL)
        }
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
}
