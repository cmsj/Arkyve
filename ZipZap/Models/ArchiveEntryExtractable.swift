//
//  ArchiveEntryDraggable.swift
//  ZipZap
//
//  Created by Chris Jones on 22/12/2024.
//
import SwiftUI
import UniformTypeIdentifiers
import ZZLog

struct ArchiveEntryExtractable {
    let showErrors: ShowErrors
    let archiveURL: URL?
    let cacheURL: URL?
    let selectedPath: String
    let entries: [ArchiveEntryFlat]

    var basePath: String { selectedPath.split(separator: "/").dropLast().joined(separator: "/") }
}

extension ArchiveEntryExtractable: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .fileURL) { entryDraggable in
            guard let archiveURL = entryDraggable.archiveURL else { return Data() }
            guard let cacheURL = entryDraggable.cacheURL else { return Data() }

            let loader = libarchive(url: archiveURL)

            do {
                let writtenURLs = try await loader.extractEntries([entryDraggable], toFolder: cacheURL)
                guard writtenURLs.count > 0 else { throw ArchiveError.ArchiveExtractError(archive: archiveURL.path, error: "Zero entries extracted")}
                #ZZTrace("Wrote \(writtenURLs.count) entries. First is \(writtenURLs.first!.dataRepresentation)")
                return writtenURLs.first!.dataRepresentation
            } catch {
                await entryDraggable.showErrors.err(ArchiveError.ArchiveDropError(msg: error.localizedDescription))
                return Data()
            }
        }
    }
}
