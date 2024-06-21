//
//  Archive.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import ZZLog

enum ArchiveError: Error {
    case ArchiveOpenError(String)
    case ArchiveEntriesError(String)
    case ArchiveExtractError(String)
}

// MARK: Sorting
extension Archive {
    // Sort our entries and return a new value, munging keypaths appropriately for the various fields of ArchiveEntry which need to be passed to Table as Strings, but don't sort well as Strings (ie dates)
    func sort(using: [KeyPathComparator<ArchiveEntry>]) {
        guard let sortDetails = using.first else { return }
        var newSort: KeyPathComparator<ArchiveEntry>

        switch (sortDetails.keyPath) {
        case \ArchiveEntry.mtime.userFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.mtime, order: sortDetails.order)
        case \ArchiveEntry.ctime.userFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.ctime, order: sortDetails.order)
        case \ArchiveEntry.atime.userFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.atime, order: sortDetails.order)
        case \ArchiveEntry.btime.userFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.btime, order: sortDetails.order)
        default:
            newSort = sortDetails
        }

        // FIXME: This should be sorting the tree, not the array
        self.entries.sort(using: [newSort])
    }
}

@Observable
class Archive: @unchecked Sendable {
    let queue = DispatchQueue(label: UUID().uuidString, qos: .userInitiated)

    var URL: URL
    var path: String
    var name: String
    var entries: [ArchiveEntry] = []
    var root: ArchiveEntry!
    var error: String? = nil
    var format: libarchiveFormat = .Unknown
    var filters: [libarchiveFilter] = []
    var cacheURL: URL

    let lock = Mutex()

    init(name: String, URL: URL) {
        self.URL = URL
        let name = URL.lastPathComponent
        self.name = name
        self.path = URL.path().removingPercentEncoding ?? "Unknown"
        self.cacheURL = SettingsManager.shared.cacheURL.appendingPathComponent(name)
        self.root = ArchiveEntry(isRoot: true, forArchive: self)

        #ZZTrace("Initialised for \(self.URL)")
    }

    deinit {
        self.close()
    }

    func open() {
        do {
            try FileManager.default.createDirectory(at: self.cacheURL, withIntermediateDirectories: true)
        } catch {
            let error = "Unable to create cache directory: \(self.cacheURL)"
            self.error = error
            #ZZError(error)
            return
        }

        Task {
            #ZZTrace("Archive::open() task on \(self.name)")
            let libarchive = libarchive(url: self.URL)
            let archiveFormat: libarchiveFormat
            let archiveFilters: [libarchiveFilter]
            let archiveEntries: [libarchiveEntry]

            do {
                (archiveFormat, archiveFilters, archiveEntries) = try await libarchive.readEntriesFormatFilters()
            } catch {
                let error = error.localizedDescription
                self.error = error
                #ZZError(error)
                return
            }

            self.lock.withLock {
                self.entries = archiveEntries.map { ArchiveEntry($0, forArchive: self) }
                self.format = archiveFormat
                self.filters = archiveFilters

                let (rootItems, remainingAll) = self.entries.filterBothwise { $0.path.countOccurrences(of: "/") == 0 }
                self.root.addChildren(rootItems)

                let (remainingDirs, remainingFiles) = remainingAll.filterBothwise { $0.type == .directory }
                self.root.addChildrenHierarchically(remainingDirs)
                self.root.addChildrenHierarchically(remainingFiles)
            }
        }
    }

    private func close() {
        #ZZTrace("Archive::close() on \(self.name)")
        do {
            try FileManager.default.removeItem(at: self.cacheURL)
        } catch {
            #ZZError("Unable to remove cache directory at: \(self.cacheURL)")
        }
    }

    func extractEntryToCache(_ entry: ArchiveEntry) async throws -> [URL] {
        return try await extractEntries([entry], toFolder: cacheURL)
    }

    // NOTE: This method doesn't throw because it's called from SwiftUI and it's better to handle the errors here
    func extractEntries(_ entries: Set<ArchiveEntry.ID>, toFolder: URL) {
        let foundEntries = self.entries.filter { entries.contains($0.id) }
        Task {
            do {
                _ = try await extractEntries(foundEntries, toFolder: toFolder)
            } catch {
                self.lock.withLock {
                    let error = "Unable to extract selected items"
                    self.error = error
                    #ZZError(error)
                }
            }
        }
    }

    func extractEntries(_ entries: [ArchiveEntry], toFolder: URL) async throws -> [URL] {
        var writtenURLS: [URL] = []

        #ZZTrace("extractEntries: extracting \(entries.count) items to: \(toFolder)")

        // Convert entries, which can be a tree, into a flat list for our libarchive walk below
        var flatEntries: [ArchiveEntry] = []
        for entry in entries {
            flatEntries += entry.flatChildren()
        }

        // Before we touch libarchive, deal with any synthetic directories first
        for (index, entry) in flatEntries.enumerated().reversed() {
            if entry.isSynthesized {
                #ZZTrace("Handling synthesised entry: \(entry.path)")

                // Whether we succeed or fail here, we don't need this again later
                flatEntries.remove(at: index)

                let folderURL = toFolder.appending(path: entry.pathComponents.joined(separator: "/"), directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                writtenURLS.append(folderURL)
            }
        }
        // We processed any synthesized entries in reverse, so we need to restore the original ordering of output URLs
        writtenURLS.reverse()

        let libarchive = libarchive(url: self.URL)
        do {
            // This needs to be += because we may have already written some URLs above
            try await writtenURLS += libarchive.extractEntries(flatEntries.map { $0.path }, toFolder: toFolder)
        } catch {
            self.lock.withLock {
                self.error = error.localizedDescription
            }
            return writtenURLS
        }

        return writtenURLS
    }

    func processInternalDrop(providers:[NSItemProvider], atIndex:Int, treeHint:[ArchiveEntry]) {
        // Process internal drops
//        let decoder = JSONDecoder()
//        let id: UUID
//
//        let group = DispatchGroup()
//        let result =
//        provider.loadDataRepresentation(for: ArchiveEntry.draggableType) { data, error in
//            guard let data = data else { return }
//            let id = try? decoder.decode(UUID.self, from: data)
//        }
    }

    func processExternalDrop(providers:[NSItemProvider], atIndex:Int, treeHint:[ArchiveEntry]) {

    }
}
