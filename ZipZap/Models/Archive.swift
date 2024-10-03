//
//  Archive.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import Synchronization
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

        let origPath: PartialKeyPath<ArchiveEntry> = sortDetails.keyPath

        switch (origPath) {
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

        self.root.sort(using: newSort)
    }
}

@Observable
@MainActor
class Archive {
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
    var dirty: Bool = false

    let lock = Mutex(true)

    init(name: String, URL: URL) {
        self.URL = URL
        let name = URL.lastPathComponent
        self.name = name
        self.path = URL.path().removingPercentEncoding ?? "Unknown"
        self.cacheURL = SettingsManager.shared.cacheURL.appendingPathComponent(name)
        self.root = ArchiveEntry(isRoot: true)

        #ZZTrace("Initialised for \(URL)")
    }

    deinit {
        DispatchQueue.main.sync {
            self.close()
        }
    }

    func open() async {
        do {
            try FileManager.default.createDirectory(at: self.cacheURL, withIntermediateDirectories: true)
        } catch {
            let error = "Unable to create cache directory: \(self.cacheURL)"
            self.error = error
            #ZZError(error)
            return
        }

//        Task {
            #ZZTrace("Archive::open() task on \(self.name)")
            let libarchive = libarchive(url: self.URL)
            let archiveFormat: libarchiveFormat
            let archiveFilters: [libarchiveFilter]
            let archiveEntries: [libarchiveHeader]

            do {
                (archiveFormat, archiveFilters, archiveEntries) = try await libarchive.readEntriesFormatFilters()
            } catch {
                let error = error.localizedDescription
                self.error = error
                #ZZError(error)
                return
            }

            self.lock.withLock { _ in
                self.entries = archiveEntries.map { ArchiveEntry($0) }
                self.format = archiveFormat
                self.filters = archiveFilters

                let (rootItems, remainingAll) = self.entries.filterBothwise { $0.path.countOccurrences(of: "/") == 0 }
                self.root.addChildren(rootItems)

                let (remainingDirs, remainingFiles) = remainingAll.filterBothwise { $0.type == .directory }
                self.root.addChildrenHierarchically(remainingDirs, for: self)
                self.root.addChildrenHierarchically(remainingFiles, for: self)

                let defaultSort: KeyPathComparator<ArchiveEntry> = KeyPathComparator(\ArchiveEntry.type.rawValue, order: .forward)
                self.sort(using: [defaultSort])
            }
//        }
    }

    private func close() {
        // These can't be inline to the ZZ macros below, otherwise we're passing `self` to a Task, and this method is called from `deinit()` which then exits with a non-zero retain count on `self.
        let name = self.name
        let cacheURL = self.cacheURL

        #ZZTrace("Archive::close() on \(name)")
        do {
            try FileManager.default.removeItem(at: cacheURL)
        } catch {
            #ZZError("Unable to remove cache directory at: \(cacheURL)")
        }
    }

    // NOTE: THIS MUST ONLY BE CALLED FROM WITHIN A MUTEX LOCKED CONTEXT
    func addSynthEntry(_ entry: ArchiveEntry) {
        self.entries.append(entry)
    }

    func extractEntryToCache(_ entry: ArchiveEntry) async throws -> [URL] {
        return try await extractEntries([entry], toFolder: cacheURL)
    }

    func extractEntriesToCache(_ entries: [ArchiveEntry]) async throws -> [URL] {
        return try await extractEntries(entries, toFolder: cacheURL)
    }

    func extractEntriesToCache(_ entries: Set<ArchiveEntry.ID>) async throws -> [URL] {
        let foundEntries = self.entries.filter { entries.contains($0.id) }
        return try await extractEntriesToCache(foundEntries)
    }

    // NOTE: This method doesn't throw because it's called from SwiftUI and it's better to handle the errors here
    func extractEntries(_ entries: Set<ArchiveEntry.ID>, toFolder: URL) async {
        let foundEntries = self.entries.filter { entries.contains($0.id) }
//        Task {
            do {
                _ = try await extractEntries(foundEntries, toFolder: toFolder)
            } catch {
                self.lock.withLock { _ in
                    let error = "Unable to extract selected items"
                    self.error = error
                    #ZZError(error)
                }
            }
//        }
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
                #ZZTrace("Handling synthesized entry: \(entry.path)")

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
            self.lock.withLock { _ in
                self.error = error.localizedDescription
            }
        }

        return writtenURLS
    }

    func processInternalDrop(providers:[NSItemProvider], atIndex:Int, treeHint:[ArchiveEntry]) {
        // FIXME: Implement
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
        self.dirty = true
    }

    func processExternalDrop(providers:[NSItemProvider], atIndex:Int, treeHint:[ArchiveEntry]) {
        // FIXME: Implement
        self.dirty = true
    }

    func removeEntries(_ entries: Set<ArchiveEntry.ID>) {
        let foundEntries = self.entries.filter { entries.contains($0.id) }
        let didRemove = self.entries.remove { foundEntries.contains($0) }
        self.root.removeChildren(foundEntries)

        if didRemove {
            self.dirty = true
        }
    }

    func addEntries(from urls: [URL]) {
        // FIXME: Implement
        self.dirty = true
    }

    func processEntryRename(_ entry: ArchiveEntry) {
        // FIXME: entry.name has updated, but entry.path and entry.pathComponents haven't.
        // We've never before had to think about any of these changing, and it seems weird that we have all three.
        // Maybe rename entry.path to entry.libarchivePath, never change it, and make entry.name a computed property
        // that works on entry.pathComponents' last value?
        print("NAME CHANGED: \(entry.name) :: \(entry.path) :: \(entry.pathComponents)")
        self.dirty = true
    }
}
