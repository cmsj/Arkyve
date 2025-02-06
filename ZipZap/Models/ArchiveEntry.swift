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

struct ArchiveEntryBackingStore {
    var id = UUID()
    var source: ArchiveEntrySource
    var children: [ArchiveEntry]? = nil
    var isExpanded = false
    var shouldFocus = false
    var path: String
    var name: String
    var pathComponents: [String] = []
    var size: Int64
    var atime = Date(timeIntervalSince1970: 0)
    var ctime = Date(timeIntervalSince1970: 0)
    var mtime = Date(timeIntervalSince1970: 0)
    var btime = Date(timeIntervalSince1970: 0)
    var perms: mode_t
    var permsString: String = "--"
    var uid: Int64?
    var gid: Int64?
    var type: ArchiveEntryType = .unknown
}

@Observable
final class ArchiveEntry: Identifiable, Sendable {
    static let draggableType = UTType(exportedAs: "net.tenshu.ZipZap.ArchiveEntry")
    private let store: Mutex<ArchiveEntryBackingStore>

    let id = UUID()
    var source: ArchiveEntrySource {
        get { store.withLock { $0.source }}
        set { store.withLock { $0.source = newValue }}
    }

    var children: [ArchiveEntry]? {
        get { store.withLock { $0.children }}
        set { store.withLock { $0.children = newValue }}
    }

    // Archives don't always contain entries for directories, but the files in them still contain nested paths
    // We'll have to synthesize directories for those, and track which ones they are
    var isSynthesized: Bool {
        get { [.Synthetic, .Root].contains(source.type) }
    }
    var isSynthesizedString: String {
        get { isSynthesized ? "Yes" : "No" }
    }

    var isExpanded: Bool {
        get { store.withLock { $0.isExpanded }}
        set { store.withLock { $0.isExpanded = newValue }}
    }
    var shouldFocus: Bool {
        get { store.withLock { $0.shouldFocus }}
        set { store.withLock { $0.shouldFocus = newValue }}
    }

    // Properties we will store for later use
    var path: String {
        get { store.withLock { $0.path }}
        set { store.withLock { $0.path = newValue }}
    }
    var name: String {
        get { store.withLock { $0.name }}
        set { store.withLock { $0.name = newValue }}
    }
    var pathComponents: [String] {
        get { store.withLock { $0.pathComponents }}
        set { store.withLock { $0.pathComponents = newValue }}
    }
    var size: Int64 {
        get { store.withLock { $0.size }}
        set { store.withLock { $0.size = newValue }}
    }

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

    var atime: Date {
        get { store.withLock { $0.atime }}
        set { store.withLock { $0.atime = newValue }}
    }
    var ctime: Date {
        get { store.withLock { $0.ctime }}
        set { store.withLock { $0.ctime = newValue }}
    }
    var mtime: Date {
        get { store.withLock { $0.mtime }}
        set { store.withLock { $0.mtime = newValue }}
    }
    var btime: Date {
        get { store.withLock { $0.btime }}
        set { store.withLock { $0.btime = newValue }}
    }
    var perms: mode_t {
        get { store.withLock { $0.perms }}
        set { store.withLock { $0.perms = newValue }}
    }
    var permsString: String {
        get { store.withLock { $0.permsString }}
        set { store.withLock { $0.permsString = newValue }}
    }

    var uid: Int64? {
        get { store.withLock { $0.uid }}
        set { store.withLock { $0.uid = newValue }}
    }
    var gid: Int64? {
        get { store.withLock { $0.gid }}
        set { store.withLock { $0.gid = newValue }}
    }

    var uidString: String {
        get { uid != nil ? "\(uid!)" : "--" }
    }
    var gidString: String {
        get { gid != nil ? "\(gid!)" : "--" }
    }

    var type: ArchiveEntryType {
        get { store.withLock { $0.type }}
        set { store.withLock { $0.type = newValue }}
    }

    let lock = Mutex(true)

    init(_ entry: libarchiveHeader) {
        store = Mutex(ArchiveEntryBackingStore(
            source: entry.source,
            path: entry.path,
            name: entry.name,
            pathComponents: entry.pathComponents,
            size: entry.size,
            atime: entry.atime,
            ctime: entry.ctime,
            mtime: entry.mtime,
            btime: entry.btime,
            perms: entry.perms,
            uid: entry.uid,
            gid: entry.gid,
            type: entry.type
        ))

        if self.type == .directory {
            // If we're a directory, we have at least zero children
            self.children = []
        }
    }

    init(path: String) {
        // Parse pathname to store our hierarchy
        let pathBits = path.split(separator: "/").map(String.init)
        let name = pathBits.last ?? "Unknown"
        let pathComponents = pathBits

        store = Mutex(ArchiveEntryBackingStore(
            source: ArchiveEntrySource(type: .Synthetic, path: path),
            path: path,
            name: name,
            pathComponents: pathComponents,
            size: -1,
            perms: 0
        ))
        self.children = []
    }

    init(isRoot: Bool) {
        store = Mutex(ArchiveEntryBackingStore(
            source: ArchiveEntrySource(type: .Root, path: "."),
            path: ".",
            name: "root",
            pathComponents: ["."],
            size: -1,
            perms: 0
        ))
        self.children = []
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

    func flatSelf() -> ArchiveEntryFlat {
        return ArchiveEntryFlat(path: self.path, isSynthesized: self.isSynthesized, header: self.asHeader())
    }

    func flatChildren() -> [ArchiveEntryFlat] {
        var flatChildren: [ArchiveEntryFlat] = []
        flatChildren.append(self.flatSelf())
        
        for child in self.children ?? [] {
            flatChildren.append(contentsOf: child.flatChildren())
        }

        return flatChildren
    }

    func asHeader() -> libarchiveHeader {
        return libarchiveHeader(source: source, type: type, path: path, name: name, pathComponents: pathComponents, size: size, atime: atime, ctime: ctime, mtime: mtime, btime: btime, uid: uid, gid: gid, perms: perms)
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
}
