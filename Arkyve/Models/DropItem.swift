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
        ProxyRepresentation { url in
            var sourceURL: URL = url
            AKTrace("User dragged a file (proxy): \(sourceURL)")

            // FIXME: In Testflight I'm seeing the non-caching path get permission denied errors. Is our security scoped access going away?
//            if sourceURL.path.hasPrefix("/var") {
//                // We are likely receiving something in a weird private temporary folder
//                // (e.g. a screenshot preview drag). Copy it to our drop cache
                sourceURL = try CacheManager.shared.cacheDropURL(sourceURL)
//            }
            return DropItem.file(sourceURL)
        }
        FileRepresentation(importedContentType: .image, shouldAttemptToOpenInPlace: true) { receivedFile in
            AKTrace("User dragged an image: \(receivedFile)")

            // FIXME: In Testflight I'm seeing the non-caching path get permission denied errors. Is our security scoped access going away?

//            if receivedFile.isOriginalFile && !receivedFile.file.path.hasPrefix("/var") {
//                AKTrace("Returning original file: \(receivedFile.file)")
//                return DropItem.file(receivedFile.file)
//            }

            // This isn't the original file, or it's in a temporary private OS cache folder,
            // so we will copy it to our drop cache
            let tempURL = try CacheManager.shared.cacheDropURL(receivedFile.file)
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
