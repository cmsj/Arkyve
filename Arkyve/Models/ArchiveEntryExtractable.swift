//
//  ArchiveEntryDraggable.swift
//  Arkyve
//
//  Created by Chris Jones on 22/12/2024.
//
import SwiftUI
import UniformTypeIdentifiers

struct ArchiveEntryExtractable: Codable, Transferable {
    let archiveURL: URL?
    let cacheURL: URL
    let selectedPath: String
    let id: UUID
    let name: String
    let entries: [ArchiveEntryFlat]
    var isCopied: Bool = false

    var basePath: String { selectedPath.split(separator: "/").dropLast().joined(separator: "/") }

    var utType: UTType
    var icon: Image {
        Image(nsImage: NSWorkspace.shared.icon(for: utType))
            .resizable()
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .archiveEntryExtractable)
        
        DataRepresentation(exportedContentType: .fileURL) { entryDraggable in
            let archiveURL = entryDraggable.archiveURL
            let cacheURL = entryDraggable.cacheURL
            let archiveIsNew = entryDraggable.archiveURL == nil

            let loader = libarchiveWrapper(url: archiveURL)

            do {
                let writtenURLs = try await loader.extract([entryDraggable], toFolder: cacheURL, archiveIsNew: archiveIsNew)
                guard writtenURLs.count > 0 else {
                    throw ArkyveError(.extract, msg: String(localized: "Zero entries extracted"))
                }
                AKTrace("Wrote \(writtenURLs.count) entries.")

                // FIXME: Are we sure the first URL here is always the topmost? It hasn't been elsewhere
                guard let firstURL = writtenURLs.first else {
                    throw ArkyveError(.entries, msg: String(localized: "Unable to retrieve written URLs"))
                }

                return firstURL.dataRepresentation
            } catch let error as ArkyveError {
                AKError(error.localizedDescription)
                throw error
            }
        }
    }
}
