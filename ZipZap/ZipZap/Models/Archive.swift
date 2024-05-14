//
//  Archive.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import os
import zzarchive

/*
 let components = path.split(separator: "/").map(String.init) //split path in components by '/''
         var currentFolder = rootFolder //set root folder

         for component in components {

             if let existingFolder = currentFolder.Children.first(where: { $0.name == component }) {
                 currentFolder = existingFolder
             } else {
                 let newFolder = TreeItem(name: component)
                 currentFolder.Children.append(newFolder)
                 currentFolder = newFolder
             }

         }
 */

//extension Array where Element == ArchiveEntry {
//    func childForName(_ name: String) -> ArchiveEntry? {
//        return self.first(where: { childEntry in
//            childEntry.name == name
//        })
//    }
//
//    func addEntry(_ entry: ArchiveEntry) {
//        let node = self
//        for part in entry.pathComponents {
//            if let parent = node.childForName(part) {
//
//            }
//        }
//    }
//}

class Archive: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Archive.self)
    )

    @Published var URL: URL
    @Published var name: String
    @Published var entries: [ArchiveEntry] = []
    @Published var error: String? = nil
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
                    DispatchQueue.main.async {
                        self.entries.append(newEntry)
                    }
                }
                archive_read_data_skip(self.archive)
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
    }

    func setURL(_ url: URL) {
        self.close() // We might already have an archive, and this is safe to call if not
        self.URL = url
        self.name = URL.lastPathComponent
        self.open()
    }

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
