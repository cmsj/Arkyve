//
//  ArchiveViewModel+Operations.swift
//  Arkyve
//
//  Created by Chris Jones on 09/06/2025.
//

import AppKit

extension ArchiveViewModel {
    // MARK: - Archive structure operations
    // Sort our entries and return a new value, munging keypaths appropriately for the various fields of ArchiveEntry which need to be passed to Table as Strings, but don't sort well as Strings (ie dates)
    func sort(using: [KeyPathComparator<ArchiveEntry>]? = nil) {
        guard let sortDetails = (using ?? sortOrder).first else { return }
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

        root.sort(using: newSort)
    }

    func newFolder(at parentID: UUID) -> UUID? {
        if let parentEntry = self.entryForID(parentID), parentEntry.children != nil {
            let name = "Untitled Folder"
            let pathComponents = parentEntry.pathComponents + [name]
            let path = pathComponents.joined(separator: "/")
            let entryHeader = libarchiveHeader(source: ArchiveEntrySource(type: .InMemory, pathInArchive: path),
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

            if settingsManager.folderExpansion == .always {
                entry.isExpanded = true
            }
            return entry.id
        }

        return nil
    }

    // It's unusual to have something throwing here, but we want to
    // surface a rename failure up to the UI so it can keep the item focused
    func renameEntry(of entry: ArchiveEntry) throws(ArkyveError) {
        do {
            try processEntryRename(entry)
            if errors.error?.kind == .rename {
                errors.error = nil
            }
            sort()
        } catch {
            entry.proposedName = entry.name
            errors.err(error)
            throw error
        }
    }

    func processEntryRename(_ entry: ArchiveEntry) throws(ArkyveError) {
        guard entry.proposedName != "" else {
            throw .init(.rename, msg: String(localized: "Filename must not be empty"))
        }

        // We can bail early if nothing actually changed
        guard entry.proposedName != entry.name else { return }

        // Get the parent's path components (if any)
        let parentPathComponents = entry.pathComponents.dropLast()

        // Update the path with the new name
        let newPathComponents = Array(parentPathComponents + [entry.proposedName])

        // Check if the user has renamed us to a duplicate of another name
        let possibleDuplicateEntries = self.entries.filter {
            $0.pathComponents == newPathComponents && $0.id != entry.id
        }
        if !possibleDuplicateEntries.isEmpty {
            throw .init(.rename, msg: String(localized: "\(entry.proposedName) already exists"))
        }

        entry.pathComponents = newPathComponents
        entry.name = entry.proposedName

        // Mark the archive as dirty since we've made changes
        self.setDirty()
    }

    func addFiles(from urls: [URL], parent: ArchiveEntry? = nil) throws (ArkyveError) {
        guard urls.count > 0 else { return }

        var newEntries: [ArchiveEntry] = []
        let targetEntry = parent ?? root

        for url in urls {
            let pathComponentsInArchive = targetEntry.pathComponents + [url.lastPathComponent]

            try? scopedURLManager.store(url, forOperation: .addFiles)
            guard let entry = try? ArchiveEntry(from: url, pathInArchiveComponents: pathComponentsInArchive) else {
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
                    guard let entry = try? ArchiveEntry(from: fileURL,
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

    func removeEntries(_ entriesToRemove: Set<ArchiveEntry.ID>) {
        guard entriesToRemove.count > 0 else { return }

        // FIXME: We're removing from the tree here, but do we need to track all the children and remove them from self.entries too?
        // Remove entries from the root tree structure by traversing the tree
        func removeFromTree(_ node: ArchiveEntry) {
            if node.children != nil {
                // Remove any direct children that match
                node.children?.removeAll { entriesToRemove.contains($0.id) }

                // Recursively check remaining children
                for child in node.children ?? [] {
                    removeFromTree(child)
                }
            }
        }

        removeFromTree(root)

        // Remove entries from the entries array
        entries.removeAll { entriesToRemove.contains($0.id) }

        // Mark the archive as dirty since we've made changes
        setDirty()
    }

    func saveArchive(to: URL, overrideFormat: libarchiveFormat = .Unknown, overrideFilters: [libarchiveFilter] = [.None], addToRecents: Bool = true) async {
        errors.clear()

        AKTrace("\(id): Saving archive to: \(to)")
        let loader = libarchiveWrapper(url: diskURL)

        // We will write out the archive to a cache location and then move it into place only if we succeed
        let writeCacheURL = cacheManager.urlForItem(cacheType: .write, itemName: to.lastPathComponent)

        progressTask = Task {
            disableUI = true
            defer {
                disableUI = false
                progressTask = nil
            }

            let (format, filters, headerMap) = metadataForSaving(overrideFormat: overrideFormat, overrideFilters: overrideFilters)

            do {
                try await loader.writeArchive(headerMap: headerMap, to: writeCacheURL, format: format, filters: filters, skipRead: diskURL == nil)

                AKTrace("Moving archive cache to final destination: \(writeCacheURL) -> \(to)")
                do {
                    _ = try FileManager.default.replaceItemAt(to, withItemAt: writeCacheURL, options: [.usingNewMetadataOnly])
                } catch {
                    do {
                        // FIXME: Add a comment here explaining why we retry with this call
                        try FileManager.default.moveItem(at: writeCacheURL, to: to)
                    } catch {
                        throw ArkyveError.init(.writeArchive, msg: error.localizedDescription)
                    }
                }

                // Update our metadata now we've saved to the final location
                didSave(to: to, format: format, filters: filters, addToRecents: addToRecents)
            } catch let error as ArkyveError {
                errors.err(error)
            } catch {
                errors.err(ArkyveError(.writeArchive, msg: error.localizedDescription))
            }
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

    func didSave(to: URL, format toFormat: libarchiveFormat, filters toFilters: [libarchiveFilter], addToRecents: Bool = true) {
        // Having written the archive, we should no longer have any entries of source type .Filesystem
        // So we'll update our entries to switch them to .Archive
        // Same for .InMemory directories

        var dropCacheCleanups: [URL] = []
        defer { cacheManager.removeCacheItems(cacheType: .drop, urls: dropCacheCleanups) }

        entries.forEach { entry in
            if (entry.source.type == .Filesystem || entry.source.type == .InMemory) {
                if entry.source.type == .Filesystem {
                    // FIXME: This doesn't cover ScopedURLManager.dropSBM entries
                    scopedURLManager.remove(entry.source.url)
                }
                // IF this entry started out as an item in our drop cache, we should now clean it up
                if cacheManager.isInDropCache(url: entry.source.url) {
                    dropCacheCleanups.append(entry.source.url)
                }

                // Update our source to the archive path
                entry.source = .init(type: .Archive, pathInArchive: entry.path)
            }
        }

        name = to.lastPathComponent
        format = toFormat
        filters = toFilters

        setClean()
        diskURL = to

        if addToRecents {
            settingsManager.addRecent(to)
        }
    }

    func copyArchive(to: URL) {
        guard let diskURL else { return }

        do {
            AKTrace("Copying \(diskURL) to \(to)")
            try FileManager.default.copyItem(at: diskURL, to: to)
            didSave(to: to, format: format, filters: filters)
        } catch {
            errors.err(.init(.writeArchive, msg: error.localizedDescription))
        }
    }

    func extractEntries(_ chosenEntries: [ArchiveEntry], destURL: URL, retainFullPath: Bool) {
        var extractableEntries: [ArchiveEntryExtractable] = []
        var overwriteAll = false

        // Filter out anything that already exists, but that the user doesn't want to overwrite
        entryLoop: for entry in chosenEntries {
            let fullDestURL = destURL.appending(path: retainFullPath ? entry.path : entry.name)

            // Check if fullDestURL exists, if it does, show an alert to ask the user if we should overwrite
            let fullDestExists = try? fullDestURL.checkResourceIsReachable()
            if !overwriteAll && fullDestExists == true {
                let alert = NSAlert()
                alert.addButton(withTitle: "Replace")
                alert.addButton(withTitle: "Replace All")
                alert.addButton(withTitle: "Skip")

                alert.buttons[0].hasDestructiveAction = true
                alert.buttons[1].hasDestructiveAction = true
                alert.messageText = "File already exists"
                alert.informativeText = "Do you want to replace \(fullDestURL.path)"
                alert.alertStyle = .critical

                let response = alert.runModal()
                switch response {
                case .alertFirstButtonReturn:
                    break
                case .alertSecondButtonReturn:
                    overwriteAll = true
                case .alertThirdButtonReturn:
                    continue entryLoop
                default:
                    AKError("Unknown response \(response.rawValue)")
                    return
                }
            }

            let extractableEntry = entry.asExtractable(from: diskURL, cacheURL: cacheURL)
            extractableEntries.append(extractableEntry)
        }

        if extractableEntries.count == 0 {
            // We have nothing left to do
            return
        }

        progressTask = Task {
            disableUI = true
            defer {
                disableUI = false
                progressTask = nil
            }

            do {
                let _ = try await extract(extractables: extractableEntries, toFolder: destURL, retainFullPath: retainFullPath)
            } catch let error as ArkyveError {
                errors.err(error)
            } catch {
                errors.err(.init(.extract, msg: error.localizedDescription))
            }
        }
    }

    // MARK: - Helper methods for extraction
    func extract(paths: [String], toFolder: URL,
                 retainFullPath:Bool = false) async throws(ArkyveError) -> [URL] {
        let extractables = entries.compactMap { entry in
            paths.contains(entry.path) ? entry.asExtractable(from: diskURL, cacheURL: cacheURL) : nil
        }

        return try await extract(extractables: extractables, toFolder: toFolder,
                                 retainFullPath: retainFullPath)
    }

    func extract(entries: [ArchiveEntry], toFolder: URL,
                 retainFullPath: Bool = false) async throws(ArkyveError) -> [URL] {
        let extractables = entries.map { $0.asExtractable(from: diskURL, cacheURL: cacheURL) }
        return try await extract(extractables: extractables, toFolder: toFolder,
                                 retainFullPath: retainFullPath)
    }

    func extract(toFolder: URL, retainFullPath: Bool = false) async throws(ArkyveError) -> [URL] {
        guard let rootEntries = root.children else { throw ArkyveError(.extract, msg: "Unable to find archive contents")}
        let extractables = rootEntries.map { $0.asExtractable(from: diskURL, cacheURL: cacheURL) }

        return try await extract(extractables: extractables, toFolder: toFolder,
                                 retainFullPath: retainFullPath)
    }

    func extract(extractables: [ArchiveEntryExtractable], toFolder: URL,
                 retainFullPath: Bool = false) async throws(ArkyveError) -> [URL] {
        let loader = libarchiveWrapper(url: diskURL)
        return try await loader.extract(extractables, toFolder: toFolder,
                                        retainFullPath: retainFullPath, archiveIsNew: diskURL == nil)
    }

    func resetQuickLook() {
        quickLookURL = nil
        quickLookItems = []
    }

    func extractForQuicklook() {
        let chosenEntries = entries.filter { selectedEntries.contains($0.id) }
        quickLookItems = []

        Task {
            do {
                quickLookItems += try await extract(entries: chosenEntries, toFolder: cacheURL)
                if !quickLookItems.isEmpty {
                    quickLookURL = quickLookItems.first
                }
            } catch let error as ArkyveError {
                errors.err(error)
            } catch {
                errors.err(.init(.extract, msg: error.localizedDescription))
            }
        }
    }

    func nameForQuickLook(items: Set<ArchiveEntry.ID>?) -> String {
        let first = entries.first { entry in
            entry.id == items?.first
        }
        guard let first, items?.count == 1 else { return "" }
        return " \"\(first.name)\""
    }

    func extractablesForSelected() -> [ArchiveEntryExtractable] {
        let extractables = selectedEntries.compactMap { entryID in
            if let first = entries.first(where: { $0.id == entryID }) {
                return first.asExtractable(from: diskURL, cacheURL: cacheURL)
            } else {
                return nil
            }
        }

        return extractables
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
}
