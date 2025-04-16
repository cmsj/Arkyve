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
//
//extension ArchiveEntry: Equatable {
//    static func == (lhs: ArchiveEntry, rhs: ArchiveEntry) -> Bool {
//        lhs.path == rhs.path
//    }
//}

//extension ArchiveEntry: Comparable {
//    static func < (lhs: ArchiveEntry, rhs: ArchiveEntry) -> Bool {
//        lhs.path < rhs.path
//    }
//}

//extension ArchiveEntry: Hashable {
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(path)
//    }
//}

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

    var isExpanded: Bool = false
    var shouldFocus: Bool = false

    // Properties we will store for later use
    var path: String
    var name: String
    var pathComponents: [String] = []
    var size: Int64

    var sizeString: String {
        get { size != -1 ? String(size) : "--" }
    }
    var permsString: String {
        get {
            if type == .root { return "" }
            return perms.string
        }
    }

    var atime = Date(timeIntervalSince1970: 0)
    var ctime = Date(timeIntervalSince1970: 0)
    var mtime = Date(timeIntervalSince1970: 0)
    var btime = Date(timeIntervalSince1970: 0)
    var perms: mode_t = 0

    var uid: Int64? = 0
    var gid: Int64? = 0

    var uidString: String {
        get { uid != nil ? "\(uid!)" : "--" }
    }
    var gidString: String {
        get { gid != nil ? "\(gid!)" : "--" }
    }

    var type: ArchiveEntryType

    let lock = Mutex(true)

    init(_ entry: libarchiveHeader) {
        source = entry.source
        path = entry.path
        name = entry.name
        pathComponents = entry.pathComponents
        size = entry.size
        atime = entry.atime
        ctime = entry.ctime
        mtime = entry.mtime
        btime = entry.btime
        perms = entry.perms
        uid = entry.uid
        gid = entry.gid
        type = entry.type

        if self.type == .directory {
            // If we're a directory, we have at least zero children
            self.children = []
        }
    }

    init(syntheticDirectory path: String) {
        // Parse pathname to store our hierarchy
        let pathBits = path.split(separator: "/").map(String.init)
        let name = pathBits.last ?? "Unknown"
        let pathComponents = pathBits

        self.source = ArchiveEntrySource(type: .Synthetic, path: path)
        self.path = path
        self.name = name
        self.pathComponents = pathComponents
        self.size = -1
        self.children = []
        self.type = .directory
        self.perms = 0 | S_IFDIR | S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH
    }

    init(isRoot: Bool) {
        self.source = ArchiveEntrySource(type: .Root, path: ".")
        self.path = "."
        self.name = "root"
        self.pathComponents = ["."]
        self.size = -1
        self.type = .root
        self.children = []
    }

    // Helper to create a new ArchiveEntry from a URL on the local filesystem
    convenience init?(from url: URL, archivePath: String) {
        guard let stat = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }

        let source = ArchiveEntrySource(type: .Filesystem, path: url.path)

        guard let fileSize  = (stat[FileAttributeKey.size] as? NSNumber)?.int64Value,
              let fileBtime = stat[FileAttributeKey.creationDate] as? NSDate,
              let fileMtime = stat[FileAttributeKey.modificationDate] as? NSDate,
              let fileUID   = (stat[FileAttributeKey.ownerAccountID] as? NSNumber)?.int64Value,
              let fileGID   = (stat[FileAttributeKey.groupOwnerAccountID] as? NSNumber)?.int64Value,
              var filePerms = (stat[FileAttributeKey.posixPermissions] as? NSNumber)?.uint16Value
        else { return nil }

        guard let rawType = stat[FileAttributeKey.type] as? String else { return nil }
        let fileType = FileAttributeType(rawValue: rawType)
        let entryType: ArchiveEntryType
        switch fileType {
        case .typeSocket:
            entryType = .socket
            filePerms |= S_IFSOCK
        case .typeRegular:
            entryType = .file
            filePerms |= S_IFREG
        case .typeDirectory:
            entryType = .directory
            filePerms |= S_IFDIR
        case .typeSymbolicLink:
            entryType = .symlink
            filePerms |= S_IFLNK
        case .typeCharacterSpecial:
            entryType = .chardev
            filePerms |= S_IFCHR
        case .typeBlockSpecial:
            entryType = .blockdev
            filePerms |= S_IFBLK
        case .typeUnknown:
            entryType = .unknown
        default:
            entryType = .unknown
        }

        let archivePathComponents = archivePath.components(separatedBy: "/")
        let name = archivePathComponents.last ?? archivePath // Pretty sure this will always hit the optional default case, but just in case
        let header = libarchiveHeader(source: source,
                                      type: entryType,
                                      path: archivePath,
                                      name: name,
                                      pathComponents: archivePathComponents,
                                      size: fileSize,
                                      atime: Date(timeIntervalSince1970: 0),
                                      ctime: Date(timeIntervalSince1970: 0),
                                      mtime: fileMtime as Date,
                                      btime: fileBtime as Date,
                                      uid: fileUID, gid: fileGID,
                                      perms: filePerms)

        self.init(header)
    }

    @discardableResult func addChildrenHierarchically(_ entries: [ArchiveEntry]) throws -> [ArchiveEntry] {
        return try entries.flatMap { try self.addChildHierarchically($0) }
    }

    @discardableResult func addChildHierarchically(_ entry: ArchiveEntry) throws -> [ArchiveEntry] {
        guard [.directory, .root].contains(self.type) else {
            #ZZError("addChildHierarchically called on something other than directory/root: \(self.type)")
            throw ArchiveError.ArchiveEntriesError(archive: self.name, error: "Attempted to add a child to a non-directory/root ArchiveEntry")
        }
        guard self.children != nil else {
            #ZZError("addCH found an uninitialised children array")
            throw ArchiveError.ArchiveEntriesError(archive: self.name, error: "Attempted to add children to an ArchiveEntry which can not possess children")
        }

        var syntheticEntries: [ArchiveEntry] = []

        // We're the root and the entry isn't a root item, so find which of our children's trees this entry belongs to and dispatch it to them to handle
        if type == .root && entry.pathComponents.count > 1 {
            if let dispatchIndex = children?.firstIndex(where: { $0.type == .directory && $0.name == entry.pathComponents.first }) {
                // We have a child already that contains the next part of the item's path, so add it there
                syntheticEntries += try children?[dispatchIndex].addChildHierarchically(entry) ?? []
            } else {
                // We do not currently have a child that contains the next part of the item's path, so create a synthetic one
                let synthPath = entry.pathComponents.first!
                #ZZTrace("Creating synthetic directory \(synthPath)")

                let tmpEntry = ArchiveEntry(syntheticDirectory: synthPath)
                syntheticEntries.append(tmpEntry)

                self.lock.withLock { _ in
                    self.children?.append(tmpEntry)
                }
                syntheticEntries += try children?[children!.count - 1].addChildHierarchically(entry) ?? []
            }
            return syntheticEntries
        }

        // This entry belongs directly to us, so subsume it into our children
        if pathComponents == entry.pathComponents.dropLast() || entry.pathComponents.count == 1 {
            self.lock.withLock { _ in
                children?.append(entry)
            }
            return syntheticEntries
        }

        // This entry should belong to one of our children, figure out which to dispatch it to
        let relativePath = entry.pathComponents.subtractPath(pathComponents)
        if let dispatchIndex = children?.firstIndex(where: { $0.type == .directory && $0.name == relativePath?.first }) {
            syntheticEntries += try children?[dispatchIndex].addChildHierarchically(entry) ?? []
        } else {
            let synthPath = (self.pathComponents + [relativePath!.first!]).joined(separator: "/")
            #ZZTrace("Creating synthetic subdirectory \(synthPath)")

            let tmpEntry = ArchiveEntry(syntheticDirectory: synthPath)
            syntheticEntries.append(tmpEntry)

            self.lock.withLock { _ in
                self.children?.append(tmpEntry)
            }
            syntheticEntries += try children?[children!.count - 1].addChildHierarchically(entry) ?? []
        }

        return syntheticEntries
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

    func asExtractable(for archive: Archive?) -> ArchiveEntryExtractable {
        return ArchiveEntryExtractable(archiveURL: archive?.URL,
                                       cacheURL: archive?.cacheURL,
                                       selectedPath: self.path,
                                       id: self.id,
                                       entries: self.flatChildren())
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
