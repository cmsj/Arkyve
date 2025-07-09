//
//  ArchiveEntryDraggable.swift
//  Arkyve
//
//  Created by Chris Jones on 22/12/2024.
//
import SwiftUI
import UniformTypeIdentifiers

struct ArchiveEntryExtractable: Codable, Transferable {
    var vmID: UUID? = nil
    let archiveURL: URL?
    var archivePassphrase: String? = nil
    var cacheURL: URL? = nil
    let selectedPath: String
    let id: UUID
    let name: String
    let flatSelf: ArchiveEntryFlat
    let entries: [ArchiveEntryFlat]
    var isCopied: Bool = false

    var basePath: String { selectedPath.split(separator: "/").dropLast().joined(separator: "/") }

    var utType: UTType
    var icon: Image {
        NSWorkspace.shared.icon(for: utType).shareSheetPreviewIcon()
    }

    var sharePreview: SharePreview<Image, Never> {
        SharePreview(name, image: icon)
        // This could be an alternative if FB18415902 is ever fixed. We'd also need to uncomment the extra
        // DataRepresentation below.
        // SharePreview(name, image: self)
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .archiveEntryExtractable)
            .visibility(.ownProcess)

        // This could be used for SharePreview in the future
//        DataRepresentation(exportedContentType: .png) { entryDraggable in
//            let icon = NSWorkspace.shared.icon(for: entryDraggable.utType)
//            return icon.asSimpleBitmapWithBackground(width: 128, height: 128, background: NSColor.windowBackgroundColor).asPNGData()
//        }
//        .visibility(.ownProcess)

        FileRepresentation(contentType: .data, shouldAttemptToOpenInPlace: true) { entryDraggable in
            AKTrace("User dragged a data FileRepresentation")
            let archiveURL = entryDraggable.archiveURL
            let cacheURL = entryDraggable.cacheURL
            let archiveIsNew = entryDraggable.archiveURL == nil

            let loader = libarchiveWrapper(url: archiveURL, passphrase: nil)

            do {
                let writtenURLs = try await loader.extract([entryDraggable], toFolder: cacheURL!, archiveIsNew: archiveIsNew)
                guard writtenURLs.count > 0 else {
                    throw ArkyveError(.extract, msg: String(localized: "Zero entries extracted"))
                }
                AKTrace("Wrote \(writtenURLs.count) entries.")

                // FIXME: Are we sure the first URL here is always the topmost? It hasn't been elsewhere
                guard let firstURL = writtenURLs.first else {
                    throw ArkyveError(.entries, msg: String(localized: "Unable to retrieve written URLs"))
                }

                return SentTransferredFile(firstURL, allowAccessingOriginalFile: true)
            } catch let error as ArkyveError {
                AKError(error.localizedDescription)
                throw error
            }
        } importing: { receivedFile in
            var sourceURL: URL = receivedFile.file
            AKTrace("User dragged a file (proxy): \(sourceURL)")

            // FIXME: In Testflight I'm seeing the non-caching path get permission denied errors. Is our security scoped access going away?
            try ScopedURLManager.dropSBM.store(sourceURL, forOperation: .drop) // This should fix ^^

            if sourceURL.path.hasPrefix("/var") {
                // We are likely receiving something in a weird private temporary folder
                // (e.g. a screenshot preview drag). Copy it to our drop cache
                AKTrace("Detected transient file in private cache folder, copying to drop cache: \(sourceURL)")
                sourceURL = try CacheManager.dropCache.cacheDropURL(sourceURL)
                try ScopedURLManager.dropSBM.store(sourceURL, forOperation: .drop)
            }

            guard let entry = try? ArchiveEntry(from: sourceURL, pathInArchiveComponents: []) else {
                throw ArkyveError(.entries, msg: String(localized: "Unable to add \(sourceURL.path)"))
            }
            return entry.asExtractable(from: sourceURL, archivePassphrase: nil, cacheURL: nil, vmID: nil)
        }
    }
}
