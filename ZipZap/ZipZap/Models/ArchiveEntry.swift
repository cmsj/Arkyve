//
//  ArchiveEntry.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import os
import zzarchive

struct ArchiveEntry: Identifiable {
    var id = UUID()
    private var entry: OpaquePointer?
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ArchiveEntry.self)
    )

    // Properties we will store for later use
    var pathname: String
    var size: Int64
    var sizeString: String {
        get { size != -1 ? String(size) : "" }
    }
    var atime: Date = Date(timeIntervalSince1970: 0)
    var ctime: Date = Date(timeIntervalSince1970: 0)
    var mtime: Date = Date(timeIntervalSince1970: 0)
    var btime: Date = Date(timeIntervalSince1970: 0)

    init?(_ entry: OpaquePointer?) {
        guard entry != nil else { return nil }
        self.entry = entry

        if let pathname = archive_entry_pathname(entry) {
            self.pathname = String(cString: pathname)
        } else {
            self.pathname = "Unknown"
        }

        if archive_entry_size_is_set(entry) != 0 {
            self.size = archive_entry_size(entry)
        } else {
            self.size = -1
        }

        if archive_entry_atime_is_set(entry) != 0 {
            self.atime = Date(timeIntervalSince1970: TimeInterval(archive_entry_atime(entry)))
        }
        if archive_entry_ctime_is_set(entry) != 0 {
            self.ctime = Date(timeIntervalSince1970: TimeInterval(archive_entry_ctime(entry)))
        }
        if archive_entry_mtime_is_set(entry) != 0 {
            self.mtime = Date(timeIntervalSince1970: TimeInterval(archive_entry_mtime(entry)))
        }
        if archive_entry_birthtime_is_set(entry) != 0 {
            self.btime = Date(timeIntervalSince1970: TimeInterval(archive_entry_birthtime(entry)))
        }
    }
}
