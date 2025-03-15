//
//  ArchiveEntryDraggable.swift
//  ZipZap
//
//  Created by Chris Jones on 22/12/2024.
//
import SwiftUI
import UniformTypeIdentifiers
import ZZLog

extension UTType {
    static var archiveEntryExtractable: UTType { UTType(exportedAs: "net.tenshu.ZipZap.ArchiveEntryExtractable")}
}

struct ArchiveEntryExtractable: Codable {
    let archiveURL: URL?
    let cacheURL: URL?
    let selectedPath: String
    let id: UUID
    let entries: [ArchiveEntryFlat]

    var basePath: String { selectedPath.split(separator: "/").dropLast().joined(separator: "/") }
}

extension ArchiveEntryExtractable: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .archiveEntryExtractable)
        
        DataRepresentation(exportedContentType: .fileURL) { entryDraggable in
            guard let archiveURL = entryDraggable.archiveURL else { return Data() }
            guard let cacheURL = entryDraggable.cacheURL else { return Data() }

            let loader = libarchive(url: archiveURL)

            do {
                let writtenURLs = try await loader.extractEntries([entryDraggable], toFolder: cacheURL)
                guard writtenURLs.count > 0 else { throw ArchiveError.ArchiveExtractError(archive: archiveURL.path, error: "Zero entries extracted")}
                #ZZTrace("Wrote \(writtenURLs.count) entries.")

                guard let firstURL = writtenURLs.first else {
                    throw ArchiveError.ArchiveEntriesError(archive: archiveURL.path, error: "Unable to retrieve written URLs")
                }
                return firstURL.dataRepresentation
            } catch {
                throw ArchiveError.ArchiveDropError(msg: error.localizedDescription)
            }
        }
    }
}
