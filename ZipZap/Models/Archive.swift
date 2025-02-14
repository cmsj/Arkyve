//
//  Archive.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import SwiftUI
import Synchronization
import UniformTypeIdentifiers
import ZZLog

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

//extension Archive: Equatable {
//    nonisolated static func == (lhs: Archive, rhs: Archive) -> Bool {
//        // This is declared nonisolated to conform to the protocol, and it is accessing a read-only property so should be thread-safe.
//        return lhs.id == rhs.id
//    }
//}

@Observable
class Archive {
    let id: UUID = UUID()
    let newFilePath = "/___UNKNOWN"

    var URL: URL
    var path: String
    var name: String
    var entries: [ArchiveEntry] = []
    var root: ArchiveEntry = ArchiveEntry(isRoot: true)
    var format: libarchiveFormat = .Unknown
    var filters: [libarchiveFilter] = []
    var cacheURL: URL
    var dirty: Bool = false

    var existsOnDisk: Bool {
        URL.path != newFilePath
    }

    var canWrite: Bool {
        format.canWrite
    }

    static let readableContentTypes: [UTType] = [.bz2, .gzip, .tarArchive, .zip] // FIXME: This list is nonsense
    static let writableContentTypes: [UTType] = [.bz2, .gzip, .tarArchive, .zip] // FIXME: This list is nonsense

    init(URL: URL) {
        let name = URL.lastPathComponent
        let path = URL.path().removingPercentEncoding ?? "Unknown"
        let cacheURL = SettingsManager.shared.cacheURL.appendingPathComponent(name)

        self.URL = URL
        self.path = path
        self.name = name
        self.cacheURL = cacheURL

        #ZZTrace("Initialised for \(URL)")
    }

    convenience init() {
        let path = "/___UNKNOWN"
        self.init(URL: Foundation.URL(fileURLWithPath: path))
        self.dirty = true
    }

    deinit {
        #ZZTrace("Archive::deinit()")
//        self.close()
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

    func addSynthEntry(_ entry: ArchiveEntry) {
        self.entries.append(entry)
    }

    func populate(root: ArchiveEntry, entries: [ArchiveEntry], format: libarchiveFormat, filters: [libarchiveFilter]) {
        self.root = root
        self.entries = entries
        self.format = format
        self.filters = filters
    }

    func setDirty(_ dirty: Bool = true) {
        #ZZTrace("Marking archive dirty")
        self.dirty = dirty
    }

//    func processInternalDrop(providers:[NSItemProvider], atIndex:Int, treeHint:[ArchiveEntry]) {
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
//        self.dirty = true
//    }

//    func processExternalDrop(providers:[NSItemProvider], atIndex:Int, treeHint:[ArchiveEntry]) {
//        // FIXME: Implement
//        self.dirty = true
//    }

//    func removeEntries(_ entries: Set<ArchiveEntry.ID>) {
//        let foundEntries = self.entries.filter { entries.contains($0.id) }
//        let didRemove = self.entries.remove { foundEntries.contains($0) }
//        self.root.removeChildren(foundEntries)
//
//        if didRemove {
//            self.dirty = true
//        }
//    }
//
//    func addEntries(from urls: [URL]) {
//        // FIXME: Implement
//        self.dirty = true
//    }
//
//    func processEntryRename(_ entry: ArchiveEntry) {
//        // FIXME: entry.name has updated, but entry.path and entry.pathComponents haven't.
//        // We've never before had to think about any of these changing, and it seems weird that we have all three.
//        // Maybe rename entry.path to entry.libarchivePath, never change it, and make entry.name a computed property
//        // that works on entry.pathComponents' last value?
//        print("NAME CHANGED: \(entry.name) :: \(entry.path) :: \(entry.pathComponents)")
//        self.dirty = true
//    }
}
