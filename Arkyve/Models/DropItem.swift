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
            AKTrace("User dragged an image: \(url)")
            let tempDir = SettingsManager.shared.dropCacheURL.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let tempURL = tempDir.appendingPathComponent(url.file.lastPathComponent)
            AKTrace("Copying to cache: \(tempURL)")
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
