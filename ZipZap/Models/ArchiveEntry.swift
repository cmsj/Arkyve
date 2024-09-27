//
//  ArchiveEntry.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import Synchronization
import UniformTypeIdentifiers
import SwiftUI
import ZZLog

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
        switch (S_IFMT & rawValue) {
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

    var userString: String {
        get {
            switch (self) {
            case .unknown:
                "Unknown"
            case .file:
                "File"
            case .directory:
                "Folder"
            case .socket:
                "Socket"
            case .symlink:
                "Symlink"
            case .chardev:
                "Char dev"
            case .blockdev:
                "Block dev"
            case .fifo:
                "FIFO"
            case .root:
                ""
            }
        }
    }
}

extension Array where Element == String {
    func subtractPath(_ path: [String]) -> [String]? {
        guard self.count >= path.count else {
            #ZZError("Array::subtractPath called with a path that is longer (\(path.count)) than I am (\(self.count).")
            return nil
        }

        guard self.prefix(path.count).elementsEqual(path) else {
            #ZZError("Array::subtractPath does not start with the path provided.")
            return nil
        }

        return Array(self.suffix(from: path.count))
    }
}

//extension Array where Element == ArchiveEntry {
//    func entryForPath(_ path: String) -> (Int, ArchiveEntry)? {
//        var path = path
//        if path.last == "/" {
//            path = String(path.dropLast())
//        }
//        if let index = self.firstIndex(where: { path == $0.path }) {
//            return (index, self[index])
//        }
//        return nil
//    }
//}

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

extension ArchiveEntry: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}

// Array behaviour for inspecting first level children
extension ArchiveEntry {
    subscript(_ name: String) -> ArchiveEntry? {
        return self.children?.first(where: { $0.name == name })
    }

    func firstIndexOf(_ name: String) -> Int? {
        return self.children?.firstIndex(where: { $0.name == name })
    }
}

// Drag and drop provider
// FIXME: Should some of this logic, particularly the async parts, move to Archive? Calling archive.extractEntryToCache() for each file seems inefficient if we could instead collect up all the files, extract them in one hit and then call their completions?
extension ArchiveEntry {
    static let draggableType = UTType(exportedAs: "net.tenshu.ZipZap.ArchiveEntry")

    var itemProvider: NSItemProvider {
        let provider = NSItemProvider()
        let selfID = self.id

        // Register our internal type first, so re-arranging tables takes precedence if we're dragging to ourselves
        provider.registerDataRepresentation(forTypeIdentifier: Self.draggableType.identifier, visibility: .all) { completion in
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(selfID)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }

        // Register a generic type so we can export files to anything else
        provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
            let progress = Progress(totalUnitCount: 100)
            guard let archive = self.archive else {
                let error = "Unable to find Archive for ArchiveEntry \(self.name)"
                #ZZError(error)
                completion(nil, NSError(domain: "DragAndDrop", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
                return progress
            }

            Task {
                do {
                    let writtenURLs = try await archive.extractEntryToCache(self)
                    guard writtenURLs.count > 0 else { throw ArchiveError.ArchiveExtractError("Zero entries extracted")}
                    #ZZTrace("Reporting success")
                    progress.completedUnitCount = 100
                    completion(writtenURLs.first!.dataRepresentation, nil)
                } catch {
                    // FIXME: We're should explicitly catch ArchiveExtractError here, and feed our errors into archive.error
                    let error = "Writing failed for \(self.path): \(error)"
                    #ZZError(error)
                    completion(nil, NSError(domain: "DragAndDrop", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
                }
            }

            #ZZTrace("Returning progress")
            return progress
        }
        #ZZTrace("Item provider registered")
        return provider
    }
}

@Observable
class ArchiveEntry: Identifiable, @unchecked Sendable {
    weak var archive: Archive?
    let id = UUID()

    var children: [ArchiveEntry]? = nil
    // Archives don't always contain entries for directories, but the files in them still contain nested paths
    // We'll have to synthesize directories for those, and track which ones they are
    var isSynthesized = false

    var isExpanded = false
    var shouldFocus = false

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

    var uid: String = "--"
    var gid: String = "--"

    var type: ArchiveEntryType = .unknown

    let lock = Mutex(true)

    init(_ entry: libarchiveEntry, forArchive: Archive) {
        self.archive = forArchive
        self.path = entry.path
        self.name = entry.name
        self.pathComponents = entry.pathComponents
        self.size = entry.size
        self.atime = entry.atime
        self.mtime = entry.mtime
        self.btime = entry.btime
        self.ctime = entry.ctime
        self.perms = entry.perms
        self.uid = entry.uid
        self.gid = entry.gid
        self.type = entry.type

        if self.type == .directory {
            // If we're a directory, we have at least zero children
            self.children = []
        }
    }

    init(path: String, forArchive: Archive) {
        self.archive = forArchive
        self.isSynthesized = true
        self.type = .directory
        self.children = []
        self.path = path
        self.size = -1

        // Parse pathname to store our hierarchy
        let pathBits = path.split(separator: "/").map(String.init)
        name = pathBits.last ?? "Unknown"
        pathComponents = pathBits
    }

    init?(isRoot: Bool, forArchive: Archive) {
        guard isRoot == true else {
            #ZZError("Root ArchiveEntry initialiser called without true")
            return nil
        }
        self.archive = forArchive
        self.isSynthesized = true
        self.type = .root
        self.children = []
        self.path = "."
        self.size = -1

        pathComponents = ["."]
        name = "root"
    }

    func addChildren(_ entries: [ArchiveEntry]) {
        guard self.children != nil else {
            #ZZError("addChildren called on an ArchiveEntry which can not possess children")
            return
        }
        self.lock.withLock { _ in
            entries.forEach { self.children?.append($0) }
        }
    }

    func addChildrenHierarchically(_ entries: [ArchiveEntry]) {
        entries.forEach { self.addChildHierarchically($0) }
    }

    func addChildHierarchically(_ entry: ArchiveEntry) {
        guard [.directory, .root].contains(self.type) else {
            #ZZError("addChildHierarchically called on something other than directory/root")
            return
        }
        guard self.children != nil else {
            #ZZError("addCH found an uninitialised children array")
            return
        }

        // We're the root, so find which of our children's trees this entry belongs to and dispatch it to them to handle
        if type == .root {
            if let dispatchIndex = children?.firstIndex(where: { $0.type == .directory && $0.name == entry.pathComponents.first }) {
                children?[dispatchIndex].addChildHierarchically(entry)
            } else {
                let synthPath = entry.pathComponents.first!
                #ZZTrace("Creating synthetic root directory \(synthPath)")
                self.lock.withLock { _ in
                    self.children?.append(ArchiveEntry(path: synthPath, forArchive: self.archive!))
                }
                children?[children!.count - 1].addChildHierarchically(entry)
            }
            return
        }

        // This entry belongs directly to us, so subsume it into our children
        if pathComponents == entry.pathComponents.dropLast() {
            self.lock.withLock { _ in
                children?.append(entry)
            }
            return
        }

        // This entry should belong to one of our children, figure out which to dispatch it to
        let relativePath = entry.pathComponents.subtractPath(pathComponents)
        if let dispatchIndex = children?.firstIndex(where: { $0.type == .directory && $0.name == relativePath?.first }) {
            children?[dispatchIndex].addChildHierarchically(entry)
        } else {
            let synthPath = (self.pathComponents + [relativePath!.first!]).joined(separator: "/")
            #ZZTrace("Creating synthetic subdirectory \(synthPath)")
            self.lock.withLock { _ in
                self.children?.append(ArchiveEntry(path: synthPath, forArchive: self.archive!))
            }
            children?[children!.count - 1].addChildHierarchically(entry)
        }
    }

    func removeChildren(_ entries: [ArchiveEntry]) {
        entries.forEach { self.removeChild($0) }
    }

    func removeChild(_ entry: ArchiveEntry) {
        guard let children = children else { return }

        if let idx = children.firstIndex(of: entry) {
            #ZZTrace("Removing \(entry.name) from \(self.name)")
            self.lock.withLock { _ in
                _ = self.children?.remove(at: idx)
            }
        } else {
            for child in children {
                if child.children != nil {
                    child.removeChild(entry)
                }
            }
        }
    }

    // Return an Array of ourselves and all of our descendents.
    func flatChildren() -> [ArchiveEntry] {
        var flatChildren: [ArchiveEntry] = []
        flatChildren.append(self)

        guard self.children != nil && self.children!.count > 0 else {
            // No children, we can bail now
            return flatChildren
        }

        for child in self.children! {
            flatChildren.append(child)

            if child.children != nil && child.children!.count > 0 {
                flatChildren += child.flatChildren()
            }
        }
        return flatChildren
    }

    // Sort the tree at all levels
    func sort(using sortDetails: KeyPathComparator<ArchiveEntry>) {
        guard self.children != nil else { return }

        // First sort our children
        self.children?.sort(using: sortDetails)

        // Now tell each of our children to sort their children, recursively
        for child in self.children! {
            child.sort(using: sortDetails)
        }
    }
}
