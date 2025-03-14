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

    func addFiles(from urls: [URL]) {
        guard urls.count > 0 else { return }

        var newEntries: [ArchiveEntry] = []

        // FIXME: The inner part of this loop should be extracted to its own method because it needs to be recursive for adding directories
        for url in urls {
            let entry = createEntryForURL(url)
            guard let entry = entry else { continue }

            newEntries.append(entry)

            if entry.type == .directory {
                guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: []) else { break }
                for case let fileURL as URL in enumerator {
                    if let entry = createEntryForURL(fileURL) {
                        newEntries.append(entry)
                    }
                }
            }
        }

        // FIXME: Add entries to self.entries and add them hierarchically

        self.setDirty()
    }

    func createEntryForURL(_ url: URL) -> ArchiveEntry? {
        guard let stat = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }

        let source = ArchiveEntrySource(type: .Filesystem, path: url.path)

        let fileType = FileAttributeType(rawValue: stat[FileAttributeKey.type] as! String)
        let entryType: ArchiveEntryType

        switch fileType {
        case .typeSocket:
            entryType = .socket
        case .typeRegular:
            entryType = .file
        case .typeDirectory:
            entryType = .directory
        case .typeSymbolicLink:
            entryType = .symlink
        case .typeCharacterSpecial:
            entryType = .chardev
        case .typeBlockSpecial:
            entryType = .blockdev
        case .typeUnknown:
            entryType = .unknown
        default:
            entryType = .unknown
        }

        let fileSize = stat[FileAttributeKey.size] as! NSNumber
        let fileBtime = stat[FileAttributeKey.creationDate] as! NSDate
        let fileMtime = stat[FileAttributeKey.modificationDate] as! NSDate
        let fileUID = stat[FileAttributeKey.ownerAccountID] as! NSNumber
        let fileGID = stat[FileAttributeKey.groupOwnerAccountID] as! NSNumber
        let filePerms = stat[FileAttributeKey.posixPermissions] as! NSNumber

        let header = libarchiveHeader(source: source,
                                      type: entryType,
                                      path: url.path,
                                      name: url.pathComponents.last!,
                                      pathComponents: url.pathComponents,
                                      size: fileSize.int64Value,
                                      atime: Date(timeIntervalSince1970: 0),
                                      ctime: Date(timeIntervalSince1970: 0),
                                      mtime: fileMtime as Date,
                                      btime: fileBtime as Date,
                                      uid: fileUID.int64Value, gid: fileGID.int64Value,
                                      perms: filePerms.uint16Value)

        return ArchiveEntry(header)
    }

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
