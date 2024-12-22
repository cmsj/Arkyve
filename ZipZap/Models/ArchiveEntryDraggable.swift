//
//  ArchiveEntryDraggable.swift
//  ZipZap
//
//  Created by Chris Jones on 22/12/2024.
//
import SwiftUI
import UniformTypeIdentifiers
import ZZLog

struct ArchiveEntryDraggable {
    let archiveURL: URL?
    let cacheURL: URL?
    let entries: [ArchiveEntryFlat]
}

extension ArchiveEntryDraggable: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .fileURL) { entryDraggable in
            guard let archiveURL = entryDraggable.archiveURL else { return Data() }
            guard let cacheURL = entryDraggable.cacheURL else { return Data() }

            let loader = libarchive(url: archiveURL)
            

            var writtenURLs: [URL] = []

            let (synthPaths, realPaths) = entryDraggable.entries.filterBothwise { $0.isSynthesized == true }

            for synth in synthPaths {
                print(synth.path)
            }
            for real in realPaths {
                print(real.path)
            }

            do {
                for synthPath in synthPaths {
                    let synthURL = cacheURL.appendingPathComponent(synthPath.path)
                    try FileManager.default.createDirectory(at: synthURL, withIntermediateDirectories: true)
                    writtenURLs.append(synthURL)
                }
                writtenURLs += try await loader.extractEntries(realPaths.map { $0.path }, toFolder: cacheURL)
                guard writtenURLs.count > 0 else { throw ArchiveError.ArchiveExtractError("Zero entries extracted")}
                #ZZTrace("Wrote \(writtenURLs.count) entries. First is \(writtenURLs.first!.dataRepresentation)")
                return writtenURLs.first!.dataRepresentation
            } catch {
                #ZZError("Writing failed: \(error)")
                return Data()
            }
        }
    }
}
