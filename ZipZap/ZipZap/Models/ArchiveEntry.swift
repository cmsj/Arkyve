//
//  ArchiveEntry.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
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
    case root = "virtual root"

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
            if self == Date(timeIntervalSince1970: 0) { return "--" }
            let formatter = DateFormatter()
            // FIXME: Somehow hook up the styles to some user settings
            formatter.dateStyle = .long
            formatter.timeStyle = .long
            return formatter.string(from: self)
        }
    }
}

extension Array where Element == String {
    func subtractPath(_ path: [String]) -> [String]? {
        guard self.count >= path.count else {
            print("Array::subtractPath called with a path that is longer (\(path.count)) than I am (\(self.count).")
            return nil
        }

        guard self.prefix(path.count).elementsEqual(path) else {
            print("Array::subtractPath does not start with the path provided.")
            return nil
        }

        return Array(self.suffix(from: path.count))
    }
}

extension ArchiveEntry: Equatable {
    static func == (lhs: ArchiveEntry, rhs: ArchiveEntry) -> Bool {
        lhs.path == rhs.path
    }
}

extension ArchiveEntry: Comparable {
    static func < (lhs: ArchiveEntry, rhs: ArchiveEntry) -> Bool {
        lhs.path < rhs.path
    }
}

extension ArchiveEntry {
    subscript(_ name: String) -> ArchiveEntry? {
        return self.children?.first(where: { $0.name == name })
    }

    func firstIndexOf(_ name: String) -> Int? {
        return self.children?.firstIndex(where: { $0.name == name })
    }
}

extension ArchiveEntry: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}

extension ArchiveEntry {
    var itemProvider: NSItemProvider {
        let provider = NSItemProvider()

        provider.registerDataRepresentation(for: .fileURL, visibility: .all) { completion in
            let progress = Progress(totalUnitCount: 100)
            guard let archive = self.archive else {
                Self.logger.error("Unable to find Archive for ArchiveEntry::\(self.name)")
                completion(nil, NSError(domain: "DragAndDrop", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to find Archive for ArchiveEntry::\(self.name)"]))
                return progress
            }

            do {
                // Generate a temporary URL to write to
                // FIXME: We don't need to do the Data().write() here
                // FIXME: url is flat, where we should really replicate the hierarchy of the archive. self.pathComponents.dropLast should give us a cacheURL that can be created as a directory and then appended with self.name
                let url = archive.cacheURL.appendingPathComponent(self.name)
                try Data().write(to: url) // create temporary, emptyfile

                archive.queue.async {
                    Self.logger.trace("Writing data to \(url)")
                    do {
                        try archive.writeEntry(self, to: url)
                        Self.logger.trace("Reporting success")
                        progress.completedUnitCount = 100
                        completion(url.dataRepresentation, nil)
                    } catch {
                        Self.logger.trace("Writing failed for \(url)")
                        completion(nil, NSError(domain: "DragAndDrop", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to write to \(url)"]))
                    }
                }
            } catch {
                Self.logger.trace("item provider exception caught: \(error)")
                completion(nil, error)
            }

            Self.logger.trace("Returning progress")
            return progress
        }
        Self.logger.trace("Item provider registered")
        return provider
    }
}

@Observable
class ArchiveEntry: Identifiable {
    weak var archive: Archive?
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

    var isExpanded = false

    // Properties we will store for later use
    var path: String
    var name: String
    var pathComponents: [String] = []
    var size: Int64
    var sizeString: String {
        get { size != -1 ? String(size) : "--" }
    }
    var finalDirName: String? {
        get {
            if type == .directory {
                return name
            }
            return pathComponents.dropLast().last
        }
    }
    var atime: Date = Date(timeIntervalSince1970: 0)
    var ctime: Date = Date(timeIntervalSince1970: 0)
    var mtime: Date = Date(timeIntervalSince1970: 0)
    var btime: Date = Date(timeIntervalSince1970: 0)
    var perms: String = "--"

    var type: ArchiveEntryType = .unknown

    init?(_ entry: OpaquePointer?, forArchive: Archive) {
        guard entry != nil else { return nil }
        self.entry = entry
        self.archive = forArchive

        if var pathString = forArchive.libarchive_entry_path(entry) {
            if pathString.last == "/" {
                pathString = String(pathString.dropLast())
            }
            self.path = pathString
            Self.logger.trace("Creating ArchiveEntry for \(pathString)")

            // Parse pathname to store our hierarchy
            let pathBits = pathString.split(separator: "/").map(String.init)
            name = pathBits.last ?? "Unknown"
            pathComponents = pathBits
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

        if let modeCstring = archive_entry_strmode(entry) {
            self.perms = String(cString: modeCstring)
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
        let pathBits = path.split(separator: "/").map(String.init)
        name = pathBits.last ?? "Unknown"
        pathComponents = pathBits
    }

    init?(isRoot: Bool) {
        guard isRoot == true else {
            Self.logger.error("Root ArchiveEntry initialiser called without true")
            return nil
        }
        self.isSynthesized = true
        self.entry = nil
        self.type = .root
        self.children = []
        self.path = "."
        self.size = -1

        pathComponents = ["."]
        name = "root"
    }

    func addChildren(_ entries: [ArchiveEntry]) {
        guard self.children != nil else {
            Self.logger.error("addChildren called on an ArchiveEntry which can not possess children")
            return
        }
        entries.forEach { self.children?.append($0) }
    }

    func addChildrenHierarchically(_ entries: [ArchiveEntry]) {
        entries.forEach { self.addChildHierarchically($0) }
    }

    func addChildHierarchically(_ entry: ArchiveEntry) {
        guard [.directory, .root].contains(self.type) else {
            Self.logger.error("addChildHierarchically called on something other than directory/root")
            return
        }
        guard self.children != nil else {
            Self.logger.error("addCH found an uninitialised children array")
            return
        }

        // We're the root, so find which of our children's trees this entry belongs to and dispatch it to them to handle
        if type == .root {
            if let dispatchIndex = children?.firstIndex(where: { $0.type == .directory && $0.name == entry.pathComponents.first }) {
                children?[dispatchIndex].addChildHierarchically(entry)
            } else {
                let synthPath = entry.pathComponents.first!
                Self.logger.trace("Creating synthetic root directory \(synthPath)")
                self.children?.append(ArchiveEntry(path: synthPath))
                children?[children!.count - 1].addChildHierarchically(entry)
            }
            return
        }

        // This entry belongs directly to us, so subsume it into our children
        if pathComponents == entry.pathComponents.dropLast() {
            children?.append(entry)
            return
        }

        // This entry should belong to one of our children, figure out which to dispatch it to
        let relativePath = entry.pathComponents.subtractPath(pathComponents)
        if let dispatchIndex = children?.firstIndex(where: { $0.type == .directory && $0.name == relativePath?.first }) {
            children?[dispatchIndex].addChildHierarchically(entry)
        } else {
            let synthPath = (self.pathComponents + [relativePath!.first!]).joined(separator: "/")
            Self.logger.trace("Creating synthetic subdirectory \(synthPath)")
            self.children?.append(ArchiveEntry(path: synthPath))
            children?[children!.count - 1].addChildHierarchically(entry)
        }
    }
}
