//
//  ArchiveEntry.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import os
import zzarchive

enum ArchiveEntryType: String {
    case unknown = "questionmark"
    case file = "doc"
    case directory = "folder"
    case socket = "gearshape.2"
    case symlink = "link"
    case chardev = "chart.bar.doc.horizontal"
    case blockdev = "batteryblock"
    case fifo = "pipe.and.drop"

    init(rawValue: mode_t) {
        let compare = S_IFMT & rawValue
        switch (compare) {
        case S_IFREG:
            self = .file
        case S_IFDIR:
            self = .directory
        case S_IFSOCK:
            self = .socket
        case S_IFLNK:
            self = .symlink
        case S_IFCHR:
            self = .chardev
        case S_IFBLK:
            self = .blockdev
        case S_IFIFO:
            self = .fifo
        default:
            self = .unknown
        }
    }
}

extension Date {
    var userFormatted: String {
        get {
            let formatter = DateFormatter()
            // FIXME: Somehow hook up the styles to some user settings
            formatter.dateStyle = .long
            formatter.timeStyle = .long
            return formatter.string(from: self)
        }
    }
}

struct ArchiveEntry: Identifiable, Hashable {
    var id = UUID()
    private var entry: OpaquePointer?
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ArchiveEntry.self)
    )

    var children: [ArchiveEntry]? = nil
    // Archives don't always contain directories, but the files in them still contain paths
    // We'll have to synthesize directories for those, and track which ones they are
    var isSynthesized = false

    // Properties we will store for later use
    var path: String
    var name: String
    var pathComponents: [String] = []
    var size: Int64
    var sizeString: String {
        get { size != -1 ? String(size) : "--" }
    }
    var atime: Date = Date(timeIntervalSince1970: 0)
    var ctime: Date = Date(timeIntervalSince1970: 0)
    var mtime: Date = Date(timeIntervalSince1970: 0)
    var btime: Date = Date(timeIntervalSince1970: 0)

    var type: ArchiveEntryType = .unknown

    init?(_ entry: OpaquePointer?) {
        guard entry != nil else { return nil }
        self.entry = entry

        if let pathCstring = archive_entry_pathname(entry) {
            let pathString = String(cString: pathCstring)
            self.path = pathString
            Self.logger.trace("Creating ArchiveEntry for \(pathString)")

            // Parse pathname to store our hierarchy
            pathComponents = pathString.split(separator: "/").map(String.init)
            name = pathComponents.last ?? "Unknown"
        } else {
            self.path = "Unknown"
            self.name = "Unknown"
            Self.logger.trace("Creating ArchiveEntry for entry with no pathname")
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

        self.type = ArchiveEntryType(rawValue: archive_entry_filetype(entry))
        if self.type == .directory {
            // If we're a directory, we have at least zero children
            self.children = []
        }
    }

    init(path: String) {
        self.isSynthesized = true
        self.entry = nil
        self.type = .directory
        self.children = []
        self.path = path
        self.size = -1

        // Parse pathname to store our hierarchy
        pathComponents = path.split(separator: "/").map(String.init)
        name = pathComponents.last ?? "Unknown"
    }
}
