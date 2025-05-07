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

    func processDrop(at index: Int? = nil, on entry: ArchiveEntry? = nil, for providers: [NSItemProvider]) {
        let destUUID = entry?.id

        for provider in providers {
            // Check for the internal type first, because internal drags also have a fileURL so they can be dragged externally
            if provider.hasItemConformingToTypeIdentifier(UTType.archiveEntryExtractable.identifier) {
                _ = provider.loadTransferable(type: ArchiveEntryExtractable.self) { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let entry):
                            self.handleEntryDrop(at: index, on: destUUID, entryExtractable: entry)
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
                            self.handleFileURLDrop(at: index, on: destUUID, fileURL: url)
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
        print("HANDLING ENTRY DROPPED AT \(index ?? -1) on \(entryID?.uuidString ?? "unknown"): \(entryExtractable)")

        guard let archive = archive else { return }
        // 1. Find the current entry from the supplied extractable

        // FIXME: If we are in a cut/paste operation, there is no entry in the Archive, we need to rebuild it and parent it
        guard let entry = archive.entryForID(entryExtractable.id) else { return }

        // 2. Find the new parent
        let newParent: ArchiveEntry
        if let newParentEntryID = entryID, newParentEntryID != archive.root.id {
            // If we have an entryID, find that entry in the archive
            guard let parent = archive.entries.first(where: { $0.id == newParentEntryID }) else { return }
            newParent = parent
        } else {
            // If no entryID, or the entryID was the root, use the root
            newParent = archive.root
        }

        // FIXME: IF we are in a copy operation, we don't want to parent, we should be duplicating
        archive.reparentEntry(entry, to: newParent)
        sort()
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
