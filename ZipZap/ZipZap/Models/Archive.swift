//
//  Archive.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import os
import zzarchive

enum ArchiveError: Error {
    case TestError
    case ArchiveReadError
    case ArchiveEntryNotFound
}

// Taken from: https://stackoverflow.com/questions/26678362/how-do-i-insert-an-element-at-the-correct-position-into-a-sorted-array-in-swift/55395494#55395494
extension RandomAccessCollection where Element : Comparable {
    func insertionIndex(of value: Element) -> Index {
        var slice : SubSequence = self[...]

        while !slice.isEmpty {
            let middle = slice.index(slice.startIndex, offsetBy: slice.count / 2)
            if value < slice[middle] {
                slice = slice[..<middle]
            } else {
                slice = slice[index(after: middle)...]
            }
        }
        return slice.startIndex
    }
}

extension Array {
    func filterBothwise(_ isIncluded: (Element) throws -> Bool) rethrows -> ([Element], [Element]) {
        var included: [Element] = []
        var excluded: [Element] = []

        for element in self {
            if try isIncluded(element) {
                included.append(element)
            } else {
                excluded.append(element)
            }
        }

        return (included, excluded)
    }
}

extension String {
    func countOccurrences(of char: Character) -> Int {
        self.ranges(of: String(char)).count
    }
}

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

        Self.logger.trace("Changing sort order to \(String(describing: newSort.keyPath))::\(String(describing: newSort.order))")
        DispatchQueue.main.async {
            self.entries.sort(using: [newSort])
        }
    }
}

// FIXME: Dispatch stuff here is likely unnecessarily wrong.
@Observable
class Archive {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Archive.self)
    )
    let queue = DispatchQueue(label: UUID().uuidString, qos: .userInitiated)

    var URL: URL
    var path: String
    var name: String
    var entries: [ArchiveEntry] = []
    var root: ArchiveEntry = ArchiveEntry(isRoot: true)!
    var error: String? = nil
    private var fd: Int32 = -1
    var cacheURL: URL

    init(name: String, URL: URL) {
        self.URL = URL
        let name = URL.lastPathComponent
        self.name = name
        self.path = URL.path().removingPercentEncoding ?? "Unknown"
        self.cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        Self.logger.trace("Initialised for \(self.URL)")
    }

    deinit {
        self.close()
    }

    func open() {
        var archive: OpaquePointer? = nil

        do {
            try FileManager.default.createDirectory(at: self.cacheURL, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Unable to create cache directory: \(self.cacheURL)")
            self.error = "Unable to create cache directory"
            return
        }

        // Process the archive on a background thread
        queue.async {
            var entry: OpaquePointer?
            Self.logger.trace("Opening: \(self.path)")

            // Prepare libarchive's data structure
            archive = archive_read_new()
            if archive == nil {
                Self.logger.error("Unable to allocate archive memory")
                return
            }
            archive_read_support_filter_all(archive)
            archive_read_support_format_all(archive)

            Self.logger.trace("Reading: \(self.path)")
            self.fd = Darwin.open(self.path, O_RDONLY)
            if self.fd < 0 {
                DispatchQueue.main.async {
                    let errorStr = "Unable to open \(self.path): \(errno)"
                    self.error = errorStr
                    Self.logger.error("Unable to open \(self.path): \(errno)")
                }
                archive_read_free(archive)
                return
            }

            let ptr = archive_read_open_fd(archive, self.fd, 10240)
            if ptr != ARCHIVE_OK {
                let cError = archive_error_string(archive)

                // We have to dispatch back to the main thread to update something that will update the UI
                DispatchQueue.main.async {
                    guard cError != nil else { return }
                    let errorStr = String(cString: cError!)
                    self.error = errorStr
                    Self.logger.error("Unable to open \(self.path): \(errorStr)")
                }
                archive_read_free(archive)
                return
            }

            Self.logger.trace("Walking: \(self.path)")
            while (archive_read_next_header(archive, &entry) == ARCHIVE_OK) {
                if let newEntry = ArchiveEntry(entry, forArchive: self) {
                    self.entries.insert(newEntry, at: self.entries.insertionIndex(of: newEntry))
                }
                archive_read_data_skip(archive)
            }

            // We're done with libarchive now
            archive_read_free(archive)

            // At this point, Archive.entries is a flat list, but archives can be hiearchical, so we need to collapse the list down to a tree

            // Find archive entries that aren't in a directory, merge them directly into the tree, keeping the rest for later
            let (rootItems, remainingAll) = self.entries.filterBothwise { $0.path.countOccurrences(of: "/") == 0 }
            DispatchQueue.main.async {
                self.root.addChildren(rootItems)
            }

            // Find all the entries we still need to fit into the tree, split into directories and files
            let (remainingDirs, remainingFiles) = remainingAll.filterBothwise { $0.type == .directory }

            DispatchQueue.main.async {
                Self.logger.trace("Adding remaining directories")
                self.root.addChildrenHierarchically(remainingDirs)

                print("Adding remaining files...")
                self.root.addChildrenHierarchically(remainingFiles)
            }
        }
    }

    private func close() {
        Self.logger.trace("Archive::close() on \(self.name)")
        Darwin.close(self.fd)
        do {
            try FileManager.default.removeItem(at: self.cacheURL)
        } catch {
            Self.logger.error("Unable to remove cache directory at: \(self.cacheURL)")
        }
    }

    // NOTE: This method does not use any async - it's expected to be called from places that know how to async
    // FIXME: This only works with files right now. Extend it to properly handle directories/etc
    func writeEntry(_ entry: ArchiveEntry, to: URL) throws {
        var archive: OpaquePointer? = nil
        let handle = try FileHandle(forWritingTo: to)
        var archiveEntry: OpaquePointer?

        // Get data from libarchive
        lseek(self.fd, 0, SEEK_SET)

        // Prepare libarchive's data structure
        archive = archive_read_new()
        if archive == nil {
            Self.logger.error("Unable to allocate archive memory")
            return
        }
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)

        Self.logger.trace("Reading: \(self.path)")
        self.fd = Darwin.open(self.path, O_RDONLY)
        if self.fd < 0 {
            DispatchQueue.main.async {
                let errorStr = "Unable to open \(self.path): \(errno)"
                self.error = errorStr
                Self.logger.error("Unable to open \(self.path): \(errno)")
            }
            archive_read_free(archive)
            return
        }

        Self.logger.trace("writeEntry: Re-opening archive")
        let ptr = archive_read_open_fd(archive, self.fd, 10240)
        if ptr != ARCHIVE_OK {
            let errStr = String(cString: archive_error_string(archive))
            Self.logger.trace("writeEntry: Unable to open archive (\(ptr)): \(errStr)")
            throw ArchiveError.ArchiveReadError
        }

        var asize: Int?
        var adata: UnsafeMutablePointer<UInt8>?

        Self.logger.trace("writeEntry: Reading archive headers...")
        while (archive_read_next_header(archive, &archiveEntry) == ARCHIVE_OK) {
            if let pathCstring = archive_entry_pathname(archiveEntry) {

                let path = String(cString: pathCstring)
                if path == entry.path {
                    asize = Int(archive_entry_size(archiveEntry));
                    guard let asize = asize else {
                        Self.logger.error("writeEntry: Unable to get size for \(path)")
                        continue
                    }
                    adata = UnsafeMutablePointer<UInt8>.allocate(capacity: asize)
                    Self.logger.trace("writeEntry: Reading archive entry...")
                    archive_read_data(archive, adata, asize);
                    break;
                }
            } else {
                Self.logger.error("writeEntry: Unable to get pathname for entry")
            }
        }

        // We're done with libarchive at this point
        archive_read_free(archive)

        guard let asize = asize, let adata = adata else {
            throw ArchiveError.ArchiveEntryNotFound
        }

        Self.logger.trace("writeEntry: Writing entry to \(to)")
        let fileData = Data(bytes: adata, count: asize)
        try handle.write(contentsOf: fileData)
        Self.logger.trace("writeEntry: Written to \(to)")
    }
}
