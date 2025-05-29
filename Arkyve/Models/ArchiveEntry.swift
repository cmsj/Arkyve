//
//  ArchiveEntry.swift
//  Arkyve
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import Synchronization
import UniformTypeIdentifiers
import SwiftUI

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
    var permsPopoverShowing: Bool = false
    var mtimePopoverShowing: Bool = false
    var ctimePopoverShowing: Bool = false
    var atimePopoverShowing: Bool = false
    var btimePopoverShowing: Bool = false

    // Properties we will store for later use
    var name: String
    private(set) var path: String
    var pathComponents: [String] = [] {
        didSet {
            path = pathComponents.joined(separator: "/")
        }
    }

    var size: Int64
    var sizeString: String {
        get { size != -1 ? String(size) : "--" }
    }
    var sizeStringHuman: String {
        get {
            // Define the units and the base for calculation
            let units = ["bytes", "KB", "MB", "GB", "TB", "PB", "EB"]
            let base: Double = 1024.0

            // Handle non-positive values
            if type == .directory {
                return "--"
            }
            guard size > 0 else {
                return "0 bytes"
            }

            // Calculate the exponent and the value
            let exponent = Int(log(Double(size)) / log(base))
            // Ensure exponent doesn't exceed available units
            let unitIndex = min(exponent, units.count - 1)
            let value = Double(size) / pow(base, Double(unitIndex))

            // Format the number
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            // Show integer if value is whole (e.g., 1MB instead of 1.0MB)
            formatter.minimumFractionDigits = 0
            // Show at most one decimal place otherwise (e.g., 1.5KB)
            formatter.maximumFractionDigits = 1
            // Use rounding strategy that feels natural for file sizes
            formatter.roundingMode = .halfUp

            // Handle the base "bytes" case specifically (no decimals needed)
            if unitIndex == 0 {
                // Use the original integer value for "bytes"
                return "\(size) \(units[unitIndex])"
            } else {
                // Format the calculated value for KB, MB, etc.
                if let formattedValue = formatter.string(from: NSNumber(value: value)) {
                    return "\(formattedValue) \(units[unitIndex])"
                } else {
                    // Fallback formatting in case NumberFormatter fails
                    return String(format: "%.1f %@", value, units[unitIndex])
                }
            }
        }
    }

    var perms: mode_t = 0
    var permsString: String {
        get {
            if type == .root { return "" }
            return perms.string
        }
    }
    var permsAccessibilityString: String {
        get {
            if type == .root { return "" }
            return perms.accessibilityString
        }
    }

    var atime = Date(timeIntervalSince1970: 0)
    var ctime = Date(timeIntervalSince1970: 0)
    var mtime = Date(timeIntervalSince1970: 0)
    var btime = Date(timeIntervalSince1970: 0)

    var uid: Int64? = 0
    var gid: Int64? = 0

    var uidString: String {
        get { uid != nil ? "\(uid!)" : "--" }
    }
    var gidString: String {
        get { gid != nil ? "\(gid!)" : "--" }
    }

    var type: ArchiveEntryType
    var utType: UTType {
        switch type {
        case .directory:
            return .folder
        case .symlink:
            return .symbolicLink
        case .blockdev, .chardev, .fifo, .socket, .unknown:
            return .data
        case .root:
            return .volume
        case .file:
            return UTType(filenameExtension: name.pathExtension) ?? .data
        }
    }

    var symlinkTarget: String? = nil
    var rdev: dev_t? = nil
    var rdevString: String {
        return rdev?.description ?? "--"
    }

    var symlinkTargetString: String {
        get { symlinkTarget != nil ? "\(symlinkTarget!)" : "--"}
    }

    let lock = Mutex(true)

    init(_ entry: libarchiveHeader) {
        source = entry.source
        name = entry.name
        pathComponents = entry.pathComponents
        path = entry.pathComponents.joined(separator: "/")
        size = entry.size
        atime = entry.atime
        ctime = entry.ctime
        mtime = entry.mtime
        btime = entry.btime
        perms = entry.perms
        uid = entry.uid
        gid = entry.gid
        type = entry.type
        symlinkTarget = entry.symlinkTarget
        rdev = entry.rdev

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
        self.name = name
        self.pathComponents = pathComponents
        self.path = path
        self.size = -1
        self.children = []
        self.type = .directory
        self.perms = mode_t.directory
    }

    // periphery:ignore:parameters isRoot
    init(isRoot: Bool) {
        self.source = ArchiveEntrySource(type: .Root, path: "")
        self.name = "root"
        self.pathComponents = []
        self.path = ""
        self.size = -1
        self.type = .root
        self.children = []
    }

    // Helper to create a new ArchiveEntry from a URL on the local filesystem
    convenience init?(from url: URL, pathInArchiveComponents: [String]) {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        let attrs: [FileAttributeKey : Any]

        do {
            attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            AKError(error.localizedDescription)
            return nil
        }

        let source = ArchiveEntrySource(type: .Filesystem, path: url.path)

        guard var fileSize  = (attrs[FileAttributeKey.size] as? NSNumber)?.int64Value,
              let fileBtime = attrs[FileAttributeKey.creationDate] as? NSDate,
              let fileMtime = attrs[FileAttributeKey.modificationDate] as? NSDate,
              let fileUID   = (attrs[FileAttributeKey.ownerAccountID] as? NSNumber)?.int64Value,
              let fileGID   = (attrs[FileAttributeKey.groupOwnerAccountID] as? NSNumber)?.int64Value,
              var filePerms = (attrs[FileAttributeKey.posixPermissions] as? NSNumber)?.uint16Value
        else { return nil }

        var symlinkTarget: String? = nil
        var rdev: dev_t? = nil

        guard let rawType = attrs[FileAttributeKey.type] as? String else { return nil }
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
            symlinkTarget = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)
        case .typeCharacterSpecial:
            entryType = .chardev
            filePerms |= S_IFCHR
            var buf = stat()
            stat(url.path.cString(using: .utf8)!, &buf)
            rdev = buf.st_rdev
        case .typeBlockSpecial:
            entryType = .blockdev
            filePerms |= S_IFBLK
            var buf = stat()
            stat(url.path.cString(using: .utf8)!, &buf)
            rdev = buf.st_rdev
        case .typeUnknown:
            entryType = .unknown
        default:
            entryType = .unknown
        }

        if fileType != .typeRegular {
            fileSize = 0
        }

        let name = pathInArchiveComponents.last ?? "Unknown"
        let pathInArchive = pathInArchiveComponents.joined(separator: "/")
        let header = libarchiveHeader(source: source,
                                      type: entryType,
                                      path: pathInArchive,
                                      name: name,
                                      pathComponents: pathInArchiveComponents,
                                      size: fileSize,
                                      atime: Date(timeIntervalSince1970: 0),
                                      ctime: Date(timeIntervalSince1970: 0),
                                      mtime: fileMtime as Date,
                                      btime: fileBtime as Date,
                                      uid: fileUID, gid: fileGID,
                                      perms: filePerms,
                                      symlinkTarget: symlinkTarget,
                                      rdev: rdev)

        self.init(header)
    }

    @discardableResult func addChildrenHierarchically(_ entries: [ArchiveEntry]) throws(ArkyveError) -> [ArchiveEntry] {
        do {
            return try entries.flatMap { try self.addChildHierarchically($0) }
        } catch let error as ArkyveError {
            throw error
        } catch {
            throw .init(.entries, msg: String(localized: "Unexpected error adding children: \(error.localizedDescription)"))
        }
    }

    @discardableResult func addChildHierarchically(_ entry: ArchiveEntry) throws(ArkyveError) -> [ArchiveEntry] {
        guard [.directory, .root].contains(self.type) else {
            AKError("addChildHierarchically called on: \(self.type.userString)")
            throw .init(.entries, msg: String(localized: "Internal error, adding entry to non-directory"))
        }
        guard self.children != nil else {
            AKError("addChildHierarchically found an uninitialised children array")
            throw .init(.entries, msg: String(localized: "Internal error, adding entry to edge node"))
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
                AKTrace("Creating synthetic directory \(synthPath)")

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
            // First we need to check if this entry is a directory because we might already have created a synthetic one.
            // If we have, we'll need to reparent its children to us and remove it.
            if let dispatchIndex = children?.firstIndex(where: { $0.name == entry.name && $0.type == .directory && $0.source.type == .Synthetic }) {
                AKTrace("Replacing synthetic subdirectory \(entry.path)")
                guard let duplicate = children?[dispatchIndex] else {
                    throw .init(.readArchive, msg: String(localized: "Internal error: Duplicate synthetic directory"))
                }
                entry.children = duplicate.children
                self.lock.withLock { _ in
                    _ = self.children?.remove(at: dispatchIndex)
                }
            }
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
            AKTrace("Creating synthetic subdirectory \(synthPath)")

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
        return ArchiveEntryFlat(path: self.path, isSynthesized: self.isSynthesized, header: self.asHeader(), source: self.source)
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
        return libarchiveHeader(source: source, type: type, path: path, name: name, pathComponents: pathComponents, size: size, atime: atime, ctime: ctime, mtime: mtime, btime: btime, uid: uid, gid: gid, perms: perms, symlinkTarget: symlinkTarget, rdev: rdev)
    }

    func asExtractable(for archive: Archive) -> ArchiveEntryExtractable {
        return ArchiveEntryExtractable(archiveURL: archive.URL,
                                       cacheURL: archive.cacheURL,
                                       archviveIsNew: !archive.existsOnDisk,
                                       selectedPath: self.path,
                                       id: self.id,
                                       name: self.name,
                                       entries: self.flatChildren(),
                                       utType: self.utType
        )
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

    func hasSelfOrChildrenMatching(_ query: String) -> Bool {
        if self.path.contains(query) { return true }
        for child in self.flatChildren() {
            if child.path.contains(query) { return true }
        }
        return false
    }
}
