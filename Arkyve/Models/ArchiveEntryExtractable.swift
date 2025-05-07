//
//  ArchiveEntryDraggable.swift
//  Arkyve
//
//  Created by Chris Jones on 22/12/2024.
//
import SwiftUI
import UniformTypeIdentifiers

struct ArchiveEntryExtractable: Codable, Transferable {
    let archiveURL: URL
    let cacheURL: URL
    let selectedPath: String
    let id: UUID
    let entries: [ArchiveEntryFlat]
    var isCopied: Bool = false

    var basePath: String { selectedPath.split(separator: "/").dropLast().joined(separator: "/") }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .archiveEntryExtractable)
        
        DataRepresentation(exportedContentType: .fileURL) { entryDraggable in
            let archiveURL = entryDraggable.archiveURL
            let cacheURL = entryDraggable.cacheURL

            let loader = libarchiveWrapper(url: archiveURL)

            do {
                let writtenURLs = try await loader.extractEntries([entryDraggable], toFolder: cacheURL)
                guard writtenURLs.count > 0 else {
                    throw ArkyveError(.extract, msg: "Zero entries extracted")
                }
                AKTrace("Wrote \(writtenURLs.count) entries.")

                guard let firstURL = writtenURLs.first else {
                    throw ArkyveError(.entries, msg: "Unable to retrieve written URLs")
                }
                return firstURL.dataRepresentation
            } catch {
                throw error
            }
        }
    }
}
