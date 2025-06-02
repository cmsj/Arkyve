//
//  Archive.swift
//  Arkyve
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import SwiftUI
import Synchronization
import UniformTypeIdentifiers

// MARK: Sorting
extension Archive {
    // Sort our entries and return a new value, munging keypaths appropriately for the various fields of ArchiveEntry which need to be passed to Table as Strings, but don't sort well as Strings (ie dates)
    func sort(using: [KeyPathComparator<ArchiveEntry>]) {
        guard let sortDetails = using.first else { return }
        var newSort: KeyPathComparator<ArchiveEntry>

        let origPath: PartialKeyPath<ArchiveEntry> = sortDetails.keyPath

        switch (origPath) {
        case \ArchiveEntry.mtime.finderFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.mtime, order: sortDetails.order)
        case \ArchiveEntry.ctime.finderFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.ctime, order: sortDetails.order)
        case \ArchiveEntry.atime.finderFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.atime, order: sortDetails.order)
        case \ArchiveEntry.btime.finderFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.btime, order: sortDetails.order)
        case \ArchiveEntry.sizeString, \ArchiveEntry.sizeStringHuman:
            newSort = KeyPathComparator(\ArchiveEntry.size, order: sortDetails.order)
        default:
            newSort = sortDetails
        }

        self.root.sort(using: newSort)
    }
}

@Observable
class Archive: Identifiable {
    let id: UUID = UUID()
    static var newFilePath: String {
        let settingsManager = SettingsManager()
        return settingsManager.newFolderURL.appending(path: settingsManager.newArchiveName).path
    }

    var URL: URL
    var path: String
    var name: String
    var entries: [ArchiveEntry] = []
    var root: ArchiveEntry = ArchiveEntry(isRoot: true)
    var format: libarchiveFormat = SettingsManager().newArchiveFormat.libarchiveFormat
    var filters: [libarchiveFilter] = SettingsManager().newArchiveFilters
    var cacheURL: URL
    private(set) var dirty: Bool = false

    var isNew: Bool = false
    var existsOnDisk: Bool {
        URL.path != Archive.newFilePath
    }
    var offerTopDirectory: Bool {
        // Should extraction offer to create a directory?
        guard let children = root.children else { return false }
        switch children.count {
        case 0, 1:
            return false
        default:
            return true
        }
    }

    init(URL: URL) {
        self.URL = URL
        self.path = URL.path().removingPercentEncoding ?? "Unknown"
        self.name = URL.lastPathComponent
        self.cacheURL = CacheManager.shared.urlForItem(cacheType: .read, itemName: _name)

        AKTrace("Initialised for \(URL)")
    }

    // Create a new, empty archive
    convenience init() {
        self.init(URL: Foundation.URL(fileURLWithPath: Archive.newFilePath))
        self.isNew = true
        self.setDirty()
    }

    deinit {
        AKTrace("Archive::deinit() on \(self.name)")
        // Exit early if cacheURL doesn't exist
        guard FileManager.default.fileExists(atPath: self.cacheURL.path(percentEncoded: false)) else { return }

        do {
            try FileManager.default.removeItem(at: self.cacheURL)
        } catch {
            AKError("Unable to remove cache directory at: \(self.cacheURL.path)")
        }
    }

    func populate(root: ArchiveEntry, entries: [ArchiveEntry], format: libarchiveFormat, filters: [libarchiveFilter]) {
        self.root = root
        self.entries = entries
        self.format = format
        self.filters = filters

        // If we only have one child and it's a directory, let's expand it for a better UX
        let shouldExpand = SettingsManager().expandSingleRootFolder
        if shouldExpand, self.root.children?.count == 1, self.root.children?.first?.type == .directory {
            self.root.children?.first?.isExpanded = true
        }

        let alwaysExpand = SettingsManager().expandAllFolders
        if alwaysExpand {
            self.entries.forEach { $0.isExpanded = true }
        }
    }

    func metadataForSaving(overrideFormat: libarchiveFormat = .Unknown, overrideFilters: [libarchiveFilter] = [.None])
        -> (libarchiveFormat, [libarchiveFilter], [String:ArchiveEntryFlat])
    {
        let format = overrideFormat == .Unknown ? format : overrideFormat
        let filters = overrideFilters == [.None] ? filters : overrideFilters

        let headerMap = entries.reduce(into: [String:ArchiveEntryFlat]()) { map, entry in
            if entry.type == .root { return }
            map[entry.path] = entry.flatSelf()
        }

        return (format, filters, headerMap)
    }

    func didSave(to: URL, format: libarchiveFormat, filters: [libarchiveFilter]) {
        // Having written the archive, we should no longer have any entries of source type .Filesystem
        // So we'll update our entries to switch them to .Archive
        // Same for .InMemory directories

        var dropCacheCleanups: [String] = []
        defer { CacheManager.shared.removeCacheItems(cacheType: .drop, paths: dropCacheCleanups) }

        entries.forEach { entry in
            if (entry.source.type == .Filesystem || entry.source.type == .InMemory) {
                if entry.source.type == .Filesystem {
                    let url = Foundation.URL(fileURLWithPath: entry.source.path)
                    url.stopAccessingSecurityScopedResource()
                }
                // IF this entry started out as an item in our drop cache, we should now clean it up
                if CacheManager.shared.isInDropCache(path: entry.source.path) {
                    dropCacheCleanups.append(entry.source.path)
                }

                // Update our source to the archive path
                entry.source = .init(type: .Archive, path: entry.path)
            }
        }

        name = to.lastPathComponent
        self.format = format
        self.filters = filters

        setClean()
        isNew = false
        URL = to
    }

    func setDirty(_ dirty: Bool = true) {
        AKTrace("Marking archive \(dirty ? "dirty" : "clean")")
        self.dirty = dirty
    }

    func setClean() {
        print("Marking archive as clean")
        setDirty(false)
    }

    func addFiles(from urls: [URL], parent: ArchiveEntry? = nil) throws (ArkyveError) {
        guard urls.count > 0 else { return }

        var newEntries: [ArchiveEntry] = []
        let targetEntry = parent ?? root

        for url in urls {
            let pathComponentsInArchive = targetEntry.pathComponents + [url.lastPathComponent]

            _ = url.startAccessingSecurityScopedResource()
            guard let entry = ArchiveEntry(from: url, pathInArchiveComponents: pathComponentsInArchive) else {
                throw .init(.entries, msg: String(localized: "Unable to add \(url.path)"))
            }

            // Check if another file already has the exact same path - if it does we will forcibly rename this new one
            // (if we don't then we'll later silently drop this file when saving, because paths should be unique)
            // We do this by adding " copy", and then an incrementing number, onto the filename until we stop hitting duplicates.
            while case let existingEntry = entries.first(where: { $0.path == entry.path }), existingEntry != nil {
                entry.name.filenameMustDuplicate()
                let pathComponentsBase = entry.pathComponents.dropLast()
                entry.pathComponents = pathComponentsBase + [entry.name]

                AKTrace("Avoided duplicate path, renaming to: \(entry.name) :: \(entry.path)")
            }

            newEntries.append(entry)

            if entry.type == .directory {
                // We only want to add the directory itself, so we'll need to know its full path so we can substract that later
                let filesystemParentPath = Array(url.pathComponents.dropLast())

                guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: []) else { break }
                for case let fileURL as URL in enumerator {
                    guard var dirPathComponents = fileURL.pathComponents.subtractPath(filesystemParentPath) else {
                        throw .init(.entries, msg: String(localized: "Unable to determine file path for \(fileURL.path)"))
                    }

                    // NOTE: We are discarding the name of the directory here and replacing it with entry.name
                    // because we might have renamed it above while detecting dupes
                    dirPathComponents = [entry.name] + dirPathComponents.dropFirst()
                    guard let entry = ArchiveEntry(from: fileURL,
                                                   pathInArchiveComponents: targetEntry.pathComponents + dirPathComponents) else {
                        throw .init(.entries, msg: String(localized: "Unable to add \(fileURL.path)"))
                    }

                    newEntries.append(entry)
                }
            }
        }

        // Add directories first so we create as few synthetic directories as possible and later have to re-parent their children
        let (newDirs, newFiles) = newEntries.filterBothwise { entry in entry.type == .directory }
        do {
            try root.addChildrenHierarchically(newDirs)
            try root.addChildrenHierarchically(newFiles)
        } catch {
            throw error
        }

        entries += newEntries

        self.setDirty()
    }

    func removeEntries(_ entries: Set<ArchiveEntry.ID>) {
        guard entries.count > 0 else { return }

        // Remove entries from the root tree structure by traversing the tree
        func removeFromTree(_ node: ArchiveEntry) {
            if node.children != nil {
                // Remove any direct children that match
                node.children?.removeAll { entries.contains($0.id) }

                // Recursively check remaining children
                for child in node.children ?? [] {
                    removeFromTree(child)
                }
            }
        }
        
        removeFromTree(self.root)

        // Remove entries from the entries array
        self.entries.removeAll { entries.contains($0.id) }

        // Mark the archive as dirty since we've made changes
        self.setDirty()
    }

    func reparentEntry(_ entry: ArchiveEntry, to newParent: ArchiveEntry) {
        // 3. Remove from current parent
        func removeEntryFromParent(_ entry: ArchiveEntry) {
            // Find the parent in the archive's entries. We don't need to walk the tree, we can iterate archive.entries
            let parent = parentForEntry(entry)
//            entries.first(where: { parent in
//                parent.children?.contains(where: { $0.id == entry.id }) ?? false
//            })
            if let parent {
                parent.children?.removeAll { $0.id == entry.id }
                return
            }

            // Except in the case of root level items, because archive.root isn't in archive.entries
            if root.children?.first(where: { $0.id == entry.id }) != nil {
                // We didn't find the parent in entries, which suggests it's a root item
                root.children?.removeAll { $0.id == entry.id }
            }
        }

        func updateChildrenPathComponents(of entry: ArchiveEntry, replacing: [String], with: [String]) {
            for child in entry.children ?? [] {
                child.pathComponents = child.pathComponents.replacing(replacing, with: with)
                if child.children != nil {
                    updateChildrenPathComponents(of: child, replacing: replacing, with: with)
                }
            }
        }

        let originalParentPathComponents = Array(entry.pathComponents.dropLast())
        removeEntryFromParent(entry)

        // 4. Update pathComponents to the new parent + name
        entry.pathComponents = newParent.pathComponents + [entry.name]

        // 5. Add to new parent
        newParent.children?.append(entry)

        // Any child entries also need to have their path updated
        if entry.type == .directory {
            updateChildrenPathComponents(of: entry, replacing: originalParentPathComponents, with: newParent.pathComponents)
        }

        // Mark the archive as dirty since we've made changes
        setDirty()
    }

    func entryForID(_ id: UUID) -> ArchiveEntry? {
        if id == root.id { return root }
        return entries.first { $0.id == id }
    }

    func parentForEntry(_ entry: ArchiveEntry) -> ArchiveEntry? {
        return entries.first(where: { item in
            item.children?.contains { $0.id == entry.id } ?? false
        })
    }

    func newFolder(at parentID: UUID) -> UUID? {
        if let parentEntry = self.entryForID(parentID), parentEntry.children != nil {
            let name = "Untitled Folder"
            let pathComponents = parentEntry.pathComponents + [name]
            let path = pathComponents.joined(separator: "/")
            let entryHeader = libarchiveHeader(source: ArchiveEntrySource(type: .InMemory, path: path),
                                               type: .directory,
                                               path: path,
                                               name: name,
                                               pathComponents: pathComponents,
                                               size: 0,
                                               atime: Date.now, ctime: Date.now, mtime: Date.now, btime: Date.now,
                                               uid: Int64(getuid()), gid: Int64(getgid()),
                                               perms: mode_t.directory)
            let entry = ArchiveEntry(entryHeader)
            parentEntry.children?.append(entry)
            entries.append(entry)

            if SettingsManager().expandAllFolders {
                entry.isExpanded = true
            }
            return entry.id
        }

        return nil
    }

    func processEntryRename(_ entry: ArchiveEntry) throws(ArkyveError) {
        guard entry.name != "" else {
            throw .init(.rename, msg: String(localized: "Filename must not be empty"))
        }

        // Get the parent's path components (if any)
        let parentPathComponents = entry.pathComponents.dropLast()
        
        // Update the path with the new name
        let newPathComponents = Array(parentPathComponents + [entry.name])

        // Check if the user has renamed us to a duplicate of another name
        let possibleDuplicateEntries = self.entries.filter {
            $0.pathComponents == newPathComponents && $0.id != entry.id
        }
        if !possibleDuplicateEntries.isEmpty {
            throw .init(.rename, msg: String(localized: "\(entry.name) already exists"))
        }

        entry.pathComponents = newPathComponents

        // Mark the archive as dirty since we've made changes
        self.setDirty()
    }

    // MARK: - Helper methods for extraction
    func extract(paths: [String], toFolder: URL,
                 retainFullPath:Bool = false, archiveIsNew: Bool) async throws(ArkyveError) -> [URL] {
        let extractables = entries.compactMap { entry in
            paths.contains(entry.path) ? entry.asExtractable(for: self) : nil
        }

        return try await extract(extractables: extractables, toFolder: toFolder,
                                 retainFullPath: retainFullPath, archiveIsNew: archiveIsNew)
    }

    func extract(entries: [ArchiveEntry], toFolder: URL,
                 retainFullPath: Bool = false, archiveIsNew: Bool) async throws(ArkyveError) -> [URL] {
        let extractables = entries.map { $0.asExtractable(for: self) }
        return try await extract(extractables: extractables, toFolder: toFolder,
                                 retainFullPath: retainFullPath, archiveIsNew: archiveIsNew)
    }

    func extract(toFolder: URL, retainFullPath: Bool = false,
                 archiveIsNew: Bool) async throws(ArkyveError) -> [URL] {
        guard let rootEntries = root.children else { throw ArkyveError(.extract, msg: "Unable to find archive contents")}
        let extractables = rootEntries.map { $0.asExtractable(for: self) }

        return try await extract(extractables: extractables, toFolder: toFolder,
                                 retainFullPath: retainFullPath, archiveIsNew: archiveIsNew)
    }

    func extract(extractables: [ArchiveEntryExtractable], toFolder: URL,
                 retainFullPath: Bool = false, archiveIsNew: Bool) async throws(ArkyveError) -> [URL] {
        let loader = libarchiveWrapper(url: self.URL)
        return try await loader.extract(extractables, toFolder: toFolder,
                                        retainFullPath: retainFullPath, archiveIsNew: archiveIsNew)
    }
}
