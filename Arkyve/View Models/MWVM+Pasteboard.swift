//
//  MWVM+Pasteboard.swift
//  Arkyve
//
//  Created by Chris Jones on 07/05/2025.
//

import AppKit

extension MainWindowViewModel {
    // MARK: - Pasteboard interaction
    func extractablesToPasteboard(extractables: [ArchiveEntryExtractable]) async {
        var writers: [ArchiveEntryPasteboardWriter] = []

        do {
            for extractable in extractables {
                let fileURLData = try await extractable.exported(as: .fileURL)
                writers.append(ArchiveEntryPasteboardWriter(entry: extractable, fileURLData: fileURLData))
            }
        } catch {
            showErrors.err(.init(.extract, msg: error.localizedDescription))
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents()
        pasteboard.writeObjects(writers)
    }

    func copyButton(entries: Set<ArchiveEntry.ID>? = nil) async {
        let extractables = buildCopyable(entries: entries ?? selectedEntries)
        await extractablesToPasteboard(extractables: extractables)
    }

    func cutButton(entries: Set<ArchiveEntry.ID>? = nil) async {
        let extractables = buildCuttable(entries: entries ?? selectedEntries)
        await extractablesToPasteboard(extractables: extractables)
    }

    func buildCopyable(entries: Set<ArchiveEntry.ID>) -> [ArchiveEntryExtractable] {
        guard let archive else { return [] }
        guard entries.count > 0 else { return [] }

        let items = archive.entries.filter { entries.contains($0.id) }.map { $0.asExtractable(for: archive) }
        return items
    }

    func buildCuttable(entries: Set<ArchiveEntry.ID>) -> [ArchiveEntryExtractable] {
        guard let archive else { return [] }
        guard entries.count > 0 else { return [] }

        let items = buildCopyable(entries: entries)
        archive.removeEntries(entries)

        // Curiously, the selection binding doesn't clear automatically when we remove items from the table
        selectedEntries.removeAll()

        return items
    }
}
