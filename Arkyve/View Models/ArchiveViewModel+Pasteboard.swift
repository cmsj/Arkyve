//
//  MWVM+Pasteboard.swift
//  Arkyve
//
//  Created by Chris Jones on 07/05/2025.
//

import AppKit

extension ArchiveViewModel {
    // MARK: - Pasteboard interaction
    func extractablesToPasteboard(extractables: [ArchiveEntryExtractable]) async {
        var writers: [ArchiveEntryPasteboardWriter] = []

        do {
            for extractable in extractables {
                let fileURLData = try await extractable.exported(as: .fileURL)
                writers.append(ArchiveEntryPasteboardWriter(entry: extractable, fileURLData: fileURLData))
            }
        } catch {
            errors.err(.init(.extract, msg: error.localizedDescription))
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents()
        pasteboard.writeObjects(writers)
    }

    func copyButton(entryIDs: Set<ArchiveEntry.ID>? = nil) async {
        let extractables = buildCopyable(entryIDs: entryIDs ?? selectedEntries)
        await extractablesToPasteboard(extractables: extractables)
    }

    func cutButton(entryIDs: Set<ArchiveEntry.ID>? = nil) async {
        let extractables = buildCuttable(entryIDs: entryIDs ?? selectedEntries)
        await extractablesToPasteboard(extractables: extractables)
    }

    func buildCopyable(entryIDs: Set<ArchiveEntry.ID>) -> [ArchiveEntryExtractable] {
        guard entryIDs.count > 0 else { return [] }

        let items = entries.filter { entryIDs.contains($0.id) }.map {
            var extractable = $0.asExtractable(from: diskURL, cacheURL: cacheURL, vmID: self.id)
            extractable.isCopied = true
            return extractable
        }
        return items
    }

    func buildCuttable(entryIDs: Set<ArchiveEntry.ID>) -> [ArchiveEntryExtractable] {
        guard entryIDs.count > 0 else { return [] }

        let items = buildCopyable(entryIDs: entryIDs)
        removeEntries(entryIDs)

        // Curiously, the selection binding doesn't clear automatically when we remove items from the table
        selectedEntries.removeAll()

        return items
    }
}
