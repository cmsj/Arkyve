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

@Observable
class Archive {
    let id: UUID = UUID()
    static var newFilePath: String {
        SettingsManager.shared.newFolderURL.appending(path: SettingsManager.shared.newArchiveName).path
    }

    var URL: URL
    var path: String
    var name: String
    var entries: [ArchiveEntry] = []
    var root: ArchiveEntry = ArchiveEntry(isRoot: true)
    var format: libarchiveFormat = SettingsManager.shared.newArchiveFormat
    var filters: [libarchiveFilter] = [] // FIXME: libarchiveFilter should really give us default values for a given libarchiveFormat
    var cacheURL: URL
    var dirty: Bool = false

    var existsOnDisk: Bool {
        // FIXME: Should this actually be using FileManager.default.fileExists?
        URL.path != Archive.newFilePath
    }

    var canWrite: Bool {
        format.canWrite
    }

    init(URL: URL) {
        self.URL = URL
        self.path = URL.path().removingPercentEncoding ?? "Unknown"
        self.name = URL.lastPathComponent
        self.cacheURL = SettingsManager.shared.readCacheURL.appendingPathComponent(_name)

        #ZZTrace("Initialised for \(URL)")
    }

    // Create a new, empty archive
    convenience init() {
        self.init(URL: Foundation.URL(fileURLWithPath: Archive.newFilePath))
        self.dirty = true
    }

    deinit {
        #ZZTrace("Archive::deinit() on \(self.name)")
        // Exit early if cacheURL doesn't exist
        guard FileManager.default.fileExists(atPath: self.cacheURL.path(percentEncoded: false)) else { return }

        do {
            try FileManager.default.removeItem(at: self.cacheURL)
        } catch {
            #ZZError("Unable to remove cache directory at: \(self.cacheURL)")
        }
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

    func addFiles(from urls: [URL], pwd: URL?, parent: ArchiveEntry? = nil) throws (ArchiveError) {
        guard urls.count > 0 else { return }

        var newEntries: [ArchiveEntry] = []

        for url in urls {
            let entry = ArchiveEntry(from: url, archivePath: url.relativeTo(pwd))
            guard let entry = entry else { continue }

            newEntries.append(entry)

            if entry.type == .directory {
                guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: []) else { break }
                for case let fileURL as URL in enumerator {
                    if let entry = ArchiveEntry(from: fileURL, archivePath: fileURL.relativeTo(pwd)) {
                        newEntries.append(entry)
                    }
                }
            }
        }

        let targetEntry = parent ?? root

        // Store all the new entries
        var addedEntries: [ArchiveEntry] = []

        let (newDirs, newFiles) = newEntries.filterBothwise { entry in entry.type == .directory }
        do {
            addedEntries += try targetEntry.addChildrenHierarchically(newDirs)
            addedEntries += try targetEntry.addChildrenHierarchically(newFiles)
        } catch {
            throw ArchiveError.ArchiveEntriesError(archive: self.name, error: "Failed to add entries to root: \(error.localizedDescription)")
        }

        entries += newEntries

        self.setDirty()
    }

    func removeEntries(_ entries: Set<ArchiveEntry.ID>) {
        // Remove entries from the entries array
        self.entries.removeAll { entries.contains($0.id) }
        
        // Remove entries from the root tree structure by traversing the tree
        func removeFromTree(_ node: ArchiveEntry) {
            guard var children = node.children else { return }
            
            // Remove any direct children that match
            children.removeAll { entries.contains($0.id) }
            
            // Recursively check remaining children
            for child in children {
                removeFromTree(child)
            }
        }
        
        removeFromTree(self.root)
        
        // Mark the archive as dirty since we've made changes
        self.setDirty()
    }

    func processEntryRename(_ entry: ArchiveEntry) {
        // Get the parent's path components (if any)
        let parentPathComponents = entry.pathComponents.dropLast()
        
        // Update the path components with the new name
        entry.pathComponents = parentPathComponents + [entry.name]
        
        // Update the path by joining the components with "/"
        entry.path = entry.pathComponents.joined(separator: "/")
        
        // Mark the archive as dirty since we've made changes
        self.setDirty()
    }
}
