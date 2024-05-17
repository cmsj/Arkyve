//
//  Archive.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import os
import zzarchive

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

    var URL: URL
    var name: String
    var entries: [ArchiveEntry] = []
    var root: ArchiveEntry = ArchiveEntry(isRoot: true)!
    var error: String? = nil
    private var archive: OpaquePointer? = nil

    init(name: String, URL: URL) {
        self.URL = URL
        self.name = URL.lastPathComponent
        Self.logger.trace("Initialised for \(self.URL)")
    }

    convenience init() {
        self.init(name: "", URL: Foundation.URL(fileURLWithPath: ""))
    }

    deinit {
        guard self.archive != nil else { return }
        self.close()
    }

    private func open() {
        guard let filepath = self.URL.path().removingPercentEncoding else {
            Self.logger.error("Unable to decode URL: \(self.URL.path())")
            return
        }

        // Process the archive on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            var entry: OpaquePointer?
            Self.logger.trace("Opening: \(filepath)")

            // Prepare libarchive's data structure
            self.archive = archive_read_new()
            if self.archive == nil {
                Self.logger.error("Unable to allocate archive memory")
                return
            }
            archive_read_support_filter_all(self.archive)
            archive_read_support_format_all(self.archive)

            Self.logger.trace("Reading: \(filepath)")
            let ptr = archive_read_open_filename(self.archive, filepath, 10240)
            if ptr != ARCHIVE_OK {
                let cError = archive_error_string(self.archive)

                // We have to dispatch back to the main thread to update something that will update the UI
                DispatchQueue.main.async {
                    guard cError != nil else { return }
                    let errorStr = String(cString: cError!)
                    self.error = errorStr
                    Self.logger.error("Unable to open \(filepath): \(errorStr)")
                }
                archive_read_free(self.archive)
                self.archive = nil
                return
            }

            Self.logger.trace("Walking: \(filepath)")
            while (archive_read_next_header(self.archive, &entry) == ARCHIVE_OK) {
                if let newEntry = ArchiveEntry(entry) {
//                    DispatchQueue.main.async {
                        self.entries.insert(newEntry, at: self.entries.insertionIndex(of: newEntry))
//                    }
                }
                archive_read_data_skip(self.archive)
            }

            DispatchQueue.main.async {
                DispatchQueue.global(qos:.userInitiated).async {
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
        }
    }

    private func close() {
        Self.logger.trace("Archive::close() on \(self.name)")
        archive_read_free(self.archive)
        self.archive = nil
        self.URL = Foundation.URL(fileURLWithPath: "")
        self.name = ""
        self.entries = []
        self.root = ArchiveEntry(isRoot: true)!
    }

    func setURL(_ url: URL) {
        self.close() // We might already have an archive, and this is safe to call if not
        self.URL = url
        self.name = URL.lastPathComponent
        self.open()
    }
}
