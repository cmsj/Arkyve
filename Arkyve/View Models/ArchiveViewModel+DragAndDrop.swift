//
//  MWVM+DragAndDrop.swift
//  Arkyve
//
//  Created by Chris Jones on 07/05/2025.
//

import UniformTypeIdentifiers
import AppKit

extension ArchiveViewModel {
    // MARK: - Drag and drop (high level)
    func processDrop(at index: Int? = nil, on entryID: ArchiveEntry.ID? = nil, for providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadTransferable(type: DropItem.self, completionHandler: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let item):
                        self.handleManyDrops(on: entryID, items: [item])
                    case .failure(let error):
                        self.errors.err(.init(.drop, msg: "Failed to handle drop: \(error.localizedDescription)"))
                    }
                }
            })
        }
    }

    func handleManyDrops(on entryID: UUID? = nil, items: [DropItem]) {
        for item in items {
            switch (item) {
            case .entry(let entryExtractable):
                handleEntryDrop(on: entryID, entryExtractable: entryExtractable)
            case .file(let url):
                handleFileURLDrop(on: entryID, fileURL: url)
            default:
                errors.err(.init(.drop, msg: "Unknown drop type"))
            }
        }
    }

    // MARK: - Drag & Drop (low level)
    func handleEntryDrop(at index: Int? = nil, on entryID: UUID? = nil, entryExtractable: ArchiveEntryExtractable) {
        print("HANDLING ENTRY DROPPED at \(index ?? -1) on \(entryID?.uuidString ?? "unknown"): \(entryExtractable)")

        // Find the (new?) parent for the entries we're handling
        let newParent: ArchiveEntry
        if let newParentEntryID = entryID, newParentEntryID != root.id {
            // If we have an entryID, find that entry in the archive
            guard let parent = entries.first(where: { $0.id == newParentEntryID }) else { return }
            newParent = parent
        } else {
            // If no entryID, or the entryID was the root, use the root
            newParent = root
        }
        newParent.isExpanded = true

        // Check if we have the base extractable entry in the archive
        let entry = entryForID(entryExtractable.id)

        if entry == nil || entryExtractable.isCopied == true {
            // This entry doesn't exist in the archive, or we are doing a copy.
            // This means we must be pasting after a Cut, or we're doing a Copy.
            // so we will reconstruct ArchiveEntry objects for all of the sub-entities, fix up their path to fit
            // the parent we just identified, and add them hierarchically
            let newEntries = entryExtractable.entries.map { ArchiveEntry($0.header) }

            let newParentPathComponents = newParent.pathComponents
            let basePathComponents = entryExtractable.basePath.split(separator: "/").map(String.init)

            do {
                var modifiedEntries: [ArchiveEntry] = []
                try newEntries.forEach { newEntry in
                    guard let newPathComponents = newEntry.pathComponents.subtractPath(basePathComponents) else {
                        throw ArkyveError(.drop, msg: String(localized: "Unable to find new path for \(newEntry.path)"))
                    }
                    newEntry.pathComponents = newParentPathComponents + newPathComponents

                    // Check if another file already has the exact same path - if it does we will forcibly rename this new one
                    // (if we don't then we'll later silently drop this file when saving, because paths should be unique)
                    // We do this by adding " copy", and then an incrementing number, onto the filename until we stop hitting duplicates.
                    while case let existingEntry = entries.first(where: { $0.path == newEntry.path }), existingEntry != nil {
                        newEntry.name.filenameMustDuplicate()
                        let pathComponentsBase = newEntry.pathComponents.dropLast()
                        newEntry.pathComponents = pathComponentsBase + [newEntry.name]

                        AKTrace("Avoided duplicate path, renaming to: \(newEntry.name) :: \(newEntry.path)")
                    }

                    modifiedEntries.append(newEntry)
                }

                entries += modifiedEntries
                try root.addChildrenHierarchically(modifiedEntries)
                setDirty()
                sort()
            } catch let error as ArkyveError {
                errors.err(error)
            } catch {
                errors.err(ArkyveError(.drop, msg: error.localizedDescription))
            }

            return
        } else {
            guard let entry else { return } // This is just to make entry stop being optional

            // The base extractable entry does exist in the archive, or we're not doing a copy operation, so we can reparent in-place.
            reparentEntry(entry, to: newParent)
            sort()
        }
    }

    func handleFileURLDrop(at index: Int? = nil, on entryID: UUID? = nil, fileURL: URL) {
        print("HANDLING FILEURL DROPPED AT \(index ?? -1) on \(entryID?.uuidString ?? "unknown"): \(fileURL)")

        guard let scopedURL = try? ScopedURLManager.dropSBM.bookmarkScopedURL(fileURL) else { return }

        // 1. Find the new parent
        let newParent: ArchiveEntry
        if let entryID = entryID, entryID != root.id {
            // If we have an entryID, find that entry in the archive
            guard let parent = entries.first(where: { $0.id == entryID }) else { return }
            newParent = parent
        } else {
            // If no entryID, or entryID is the root, use the root
            newParent = root
        }

        do {
            try addFiles(from: [scopedURL], parent: newParent)
            sort()
        } catch {
            errors.err(error)
        }
    }
}
