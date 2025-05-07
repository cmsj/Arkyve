//
//  MWVM+DragAndDrop.swift
//  Arkyve
//
//  Created by Chris Jones on 07/05/2025.
//

import UniformTypeIdentifiers

extension MainWindowViewModel {
    // MARK: - Drag and drop (high level)
    func handleManyDrops(on entryID: UUID? = nil, items: [DropItem]) {
        for item in items {
            switch (item) {
            case .entry(let entryExtractable):
                handleEntryDrop(on: entryID, entryExtractable: entryExtractable)
            case .file(let url):
                handleFileURLDrop(on: entryID, fileURL: url)
            default:
                showErrors.err(.init(.drop, msg: "Unknown drop type"))
            }
        }

    }

    func processDrop(at index: Int? = nil, on entryID: ArchiveEntry.ID? = nil, for providers: [NSItemProvider]) {
        for provider in providers {
            // Check for the internal type first, because internal drags also have a fileURL so they can be dragged externally
            if provider.hasItemConformingToTypeIdentifier(UTType.archiveEntryExtractable.identifier) {
                _ = provider.loadTransferable(type: ArchiveEntryExtractable.self) { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let entry):
                            self.handleEntryDrop(at: index, on: entryID, entryExtractable: entry)
                        case .failure(let error):
                            self.showErrors.err(.init(.drop, msg: "Failed to handle drop: \(error.localizedDescription)"))
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadTransferable(type: URL.self) { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let url):
                            self.handleFileURLDrop(at: index, on: entryID, fileURL: url)
                        case .failure(let error):
                            self.showErrors.err(.init(.drop, msg: "Failed to handle drop: \(error.localizedDescription)"))
                        }
                    }
                }
            } else {
                showErrors.err(.init(.drop, msg: "Unsupported item type: \(provider.registeredTypeIdentifiers.joined(separator: ","))"))
            }
        }
    }

    // MARK: - Drag & Drop (low level)
    func handleEntryDrop(at index: Int? = nil, on entryID: UUID? = nil, entryExtractable: ArchiveEntryExtractable) {
        print("HANDLING ENTRY DROPPED at \(index ?? -1) on \(entryID?.uuidString ?? "unknown"): \(entryExtractable)")

        guard let archive = archive else { return }

        // Find the (new?) parent for the entries we're handling
        let newParent: ArchiveEntry
        if let newParentEntryID = entryID, newParentEntryID != archive.root.id {
            // If we have an entryID, find that entry in the archive
            guard let parent = archive.entries.first(where: { $0.id == newParentEntryID }) else { return }
            newParent = parent
        } else {
            // If no entryID, or the entryID was the root, use the root
            newParent = archive.root
        }
        newParent.isExpanded = true

        // Check if we have the base extractable entry in the archive
        let entry = archive.entryForID(entryExtractable.id)

        // FIXME: If we have duplicated a file inside an archive and not renamed it, it will later be silently lost. Maybe here (where the duplication happens) we should check for that and rename it?
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
                        throw ArkyveError(.drop, msg: "Unable to find new path for \(newEntry.path)")
                    }
                    newEntry.pathComponents = newParentPathComponents + newPathComponents
                    modifiedEntries.append(newEntry)
                }

                archive.entries += modifiedEntries
                try archive.root.addChildrenHierarchically(modifiedEntries)
                sort()
            } catch let error as ArkyveError {
                showErrors.err(error)
            } catch {
                showErrors.err(ArkyveError(.drop, msg: error.localizedDescription))
            }

            return
        } else {
            guard let entry else { return } // This is just to make entry stop being optional

            // The base extractable entry does exist in the archive, or we're not doing a copy operation, so we can reparent in-place.
            archive.reparentEntry(entry, to: newParent)
            sort()
        }
    }

    func handleFileURLDrop(at index: Int? = nil, on entryID: UUID? = nil, fileURL: URL) {
        print("HANDLING FILEURL DROPPED AT \(index ?? -1) on \(entryID?.uuidString ?? "unknown"): \(fileURL)")

        guard let archive = archive else { return }

        // 1. Find the new parent
        let newParent: ArchiveEntry
        if let entryID = entryID, entryID != archive.root.id {
            // If we have an entryID, find that entry in the archive
            guard let parent = archive.entries.first(where: { $0.id == entryID }) else { return }
            newParent = parent
        } else {
            // If no entryID, or entryID is the root, use the root
            newParent = archive.root
        }

        do {
            try archive.addFiles(from: [fileURL], parent: newParent)
            sort()
        } catch {
            showErrors.err(error)
        }
    }
}
