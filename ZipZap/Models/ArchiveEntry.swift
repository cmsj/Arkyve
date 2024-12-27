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
// TODO: WRITE
//extension ArchiveEntry {
//    subscript(_ name: String) -> ArchiveEntry? {
//        return self.children?.first(where: { $0.name == name })
//    }
//
//    func firstIndexOf(_ name: String) -> Int? {
//        return self.children?.firstIndex(where: { $0.name == name })
//    }
//}

@Observable
class ArchiveEntry: Identifiable {
    static let draggableType = UTType(exportedAs: "net.tenshu.ZipZap.ArchiveEntry")

    let id = UUID()
    var source: ArchiveEntrySource

    var children: [ArchiveEntry]? = nil

    // Archives don't always contain entries for directories, but the files in them still contain nested paths
    // We'll have to synthesize directories for those, and track which ones they are
    var isSynthesized: Bool {
        get { [.Synthetic, .Root].contains(source.type) }
    }
    var isSynthesizedString: String {
        get { isSynthesized ? "Yes" : "No" }
    }

    var isExpanded = false
    var shouldFocus = false

    // Properties we will store for later use
    var path: String
    nonisolated(unsafe) var name: String
    var pathComponents: [String] = []
    var size: Int64
    var sizeString: String {
        get { size != -1 ? String(size) : "--" }
    }
//    var finalDirName: String? {
//        get {
//            if type == .directory {
//                return name
//            }
//            return pathComponents.dropLast().last
//        }
//    }
    nonisolated(unsafe) var atime: Date = Date(timeIntervalSince1970: 0)
    nonisolated(unsafe) var ctime: Date = Date(timeIntervalSince1970: 0)
    nonisolated(unsafe) var mtime: Date = Date(timeIntervalSince1970: 0)
    nonisolated(unsafe) var btime: Date = Date(timeIntervalSince1970: 0)
    var perms: String = "--"

    var uid: String = "--"
    var gid: String = "--"

    nonisolated(unsafe) var type: ArchiveEntryType = .unknown

    let lock = Mutex(true)

    init(_ entry: libarchiveHeader) {
        self.source = entry.source
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

    init(path: String) {
        self.type = .directory
        self.children = []
        self.path = path
        self.size = -1
        self.source = ArchiveEntrySource(type: .Synthetic, path: path)

        // Parse pathname to store our hierarchy
        let pathBits = path.split(separator: "/").map(String.init)
        name = pathBits.last ?? "Unknown"
        pathComponents = pathBits
    }

    init(isRoot: Bool) {
        self.type = .root
        self.source = ArchiveEntrySource(type: .Root, path: ".")
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

    func addChildrenHierarchically(_ entries: [ArchiveEntry], for archive: Archive ) {
        entries.forEach { self.addChildHierarchically($0, for: archive) }
    }

    func addChildHierarchically(_ entry: ArchiveEntry, for archive: Archive) {
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
                children?[dispatchIndex].addChildHierarchically(entry, for: archive)
            } else {
                let synthPath = entry.pathComponents.first!
                #ZZTrace("Creating synthetic root directory \(synthPath)")
                let tmpEntry = ArchiveEntry(path: synthPath)

                self.lock.withLock { _ in
                    archive.addSynthEntry(tmpEntry)
                    self.children?.append(tmpEntry)
                }
                children?[children!.count - 1].addChildHierarchically(entry, for: archive)
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
            children?[dispatchIndex].addChildHierarchically(entry, for: archive)
        } else {
            let synthPath = (self.pathComponents + [relativePath!.first!]).joined(separator: "/")
            #ZZTrace("Creating synthetic subdirectory \(synthPath)")
            let tmpEntry = ArchiveEntry(path: synthPath)

            self.lock.withLock { _ in
                archive.addSynthEntry(tmpEntry)
                self.children?.append(tmpEntry)
            }
            children?[children!.count - 1].addChildHierarchically(entry, for: archive)
        }
    }

    @MainActor func flatChildren() -> [ArchiveEntryFlat] {
        var flatChildren: [ArchiveEntryFlat] = []
        let flatChild = ArchiveEntryFlat(path: self.path, isSynthesized: self.isSynthesized)
        flatChildren.append(flatChild)
        
        guard self.children != nil && self.children!.count > 0 else {
            return flatChildren
        }
        
        for child in self.children! {
            flatChildren.append(contentsOf: child.flatChildren())
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

    // TODO: WRITE
    //    func removeChildren(_ entries: [ArchiveEntry]) {
    //        entries.forEach { self.removeChild($0) }
    //    }
    //
    //    func removeChild(_ entry: ArchiveEntry) {
    //        guard let children = children else { return }
    //
    //        if let idx = children.firstIndex(of: entry) {
    //            #ZZTrace("Removing \(entry.name) from \(self.name)")
    //            self.lock.withLock { _ in
    //                _ = self.children?.remove(at: idx)
    //            }
    //        } else {
    //            for child in children {
    //                if child.children != nil {
    //                    child.removeChild(entry)
    //                }
    //            }
    //        }
    //    }

    // Return an Array of ourselves and all of our descendents.
    //    @MainActor func flatChildren() -> [ArchiveEntry] {
    //        var flatChildren: [ArchiveEntry] = []
    //        flatChildren.append(self)
    //
    //        guard self.children != nil && self.children!.count > 0 else {
    //            // No children, we can bail now
    //            return flatChildren
    //        }
    //
    //        for child in self.children! {
    //            flatChildren.append(child)
    //
    //            if child.children != nil && child.children!.count > 0 {
    //                flatChildren += child.flatChildren()
    //            }
    //        }
    //        return flatChildren
    //    }
}
