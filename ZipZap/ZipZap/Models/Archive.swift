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
    case ArchiveOpenError(String)
    case ArchiveEntriesError(String)
}

enum ArchiveEntriesAction {
    case Continue
    case Break
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

extension Archive {
    func libarchive_open() throws {
        if self.fd >= 0 {
            lseek(self.fd, 0, SEEK_SET)
        }

        // Prepare libarchive's data structure
        archive = archive_read_new()
        if archive == nil {
            throw ArchiveError.ArchiveOpenError("Unable to allocate archive memory")
        }
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)

        Self.logger.trace("Opening: \(self.path)")
        self.fd = Darwin.open(self.path, O_RDONLY)
        if self.fd < 0 {
            libarchive_close()
            throw ArchiveError.ArchiveOpenError("Unable to open \(self.path): \(errno)")
        }

        let ptr = archive_read_open_fd(archive, self.fd, 10240)
        if ptr != ARCHIVE_OK {
            let errStr = String(cString: archive_error_string(archive))
            libarchive_close()
            throw ArchiveError.ArchiveOpenError("Unable to open archive (\(ptr)): \(errStr)")
        }
    }

    func libarchive_close() {
        guard self.archive != nil else { return }
        archive_read_free(archive)
        archive = nil
    }

    func libarchive_entries(_ closure: (OpaquePointer?) throws -> ArchiveEntriesAction) throws {
        guard self.archive != nil else {
            throw ArchiveError.ArchiveEntriesError("libarchive_entries() called on a nil archive")
        }

        var entry: OpaquePointer?
        Self.logger.trace("Walking archive headers...")
        while (archive_read_next_header(self.archive, &entry) == ARCHIVE_OK) {
            if try closure(entry) == .Break {
                break
            }
        }
    }

    func libarchive_entry_path(_ entry: OpaquePointer?) -> String? {
        var string: String? = nil

        if let cString = archive_entry_pathname(entry) {
            string = String(cString: cString)
        }

        return string
    }

    func libarchive_entry_data(_ entry: OpaquePointer?) -> Data {
        let size = Int(archive_entry_size(entry))
        var rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: size)

        Self.logger.trace("Reading entry data (\(size) bytes)")
        archive_read_data(self.archive, rawData, size)

        return Data(bytes: rawData, count: size)
    }
}

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
    private var archive: OpaquePointer? = nil
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
        do {
            try FileManager.default.createDirectory(at: self.cacheURL, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Unable to create cache directory: \(self.cacheURL)")
            self.error = "Unable to create cache directory"
            return
        }

        // Process the archive on a background thread
        queue.async {
            // Initialise libarchive data structure and open our archive
            do {
                try self.libarchive_open()

                try self.libarchive_entries { entryPtr in
                    if let entry = ArchiveEntry(entryPtr, forArchive: self) {
                        self.entries.insert(entry, at: self.entries.insertionIndex(of: entry))
                    }
                    archive_read_data_skip(self.archive)
                    return .Continue
                }
            } catch ArchiveError.ArchiveOpenError(let errorMsg), ArchiveError.ArchiveEntriesError(let errorMsg) {
                DispatchQueue.main.async {
                    Self.logger.error("\(errorMsg)")
                    self.error = errorMsg
                }
            } catch {
                Self.logger.error("Unknown exception")
            }

            // We're done with libarchive now
            self.libarchive_close()

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

    // NOTE: This method does not use any async, but it is self-contained, you can call it from async places
    // FIXME: This only works with files right now. Extend it to properly handle directories/etc
    func writeEntry(_ entry: ArchiveEntry, to: URL) throws {
        let handle = try FileHandle(forWritingTo: to)

        // Initialise libarchive data structure and open our archive
        try libarchive_open()

        try libarchive_entries { entryPtr in
            if let path = libarchive_entry_path(entryPtr) {
                if path == entry.path {
                    let entryData = libarchive_entry_data(entryPtr)
                    try handle.write(contentsOf: entryData)
                    Self.logger.trace("writeEntry: Written to \(to)")
                    return .Break
                }
            }
            return .Continue
        }

        // We're done with libarchive at this point
        libarchive_close()
    }
}
