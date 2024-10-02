//
//  MainWindowViewModel.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import ZZLog

@Observable
class MainWindowViewModel {
    private(set) var archive: Archive? = nil
    var selectedEntries = Set<ArchiveEntry.ID>()
    var quickLookURL: URL?
    var quickLookItems: [URL] = []

    var newFolderURL: URL {
        get {
            UserDefaults.standard.url(forKey: "newFolderURL") ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        set(url) {
            UserDefaults.standard.setValue(url, forKey: "newFolderURL")
        }
    }

    func openArchive(url: URL) async {
        let name = url.lastPathComponent
        archive = Archive(name: name, URL: url)
//        Task {
            await archive?.open()
//        }
    }

    @MainActor func newButton() {
        archive = Archive(name: "___UNKNOWN", URL: URL(fileURLWithPath: "/___UNKNOWN"))
    }

    @MainActor func openButton() {
        if (archive != nil) {
            archive?.error = "lol"
        } else {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            if panel.runModal() == .OK {
                if let url = panel.url {
                    Task { @MainActor in
                        await openArchive(url: url)
                    }
                }
            }
        }
    }

    @MainActor func revertButton() {
        guard archive != nil else { return }
        if let url = archive?.URL {
            archive = nil
            Task { @MainActor in
                await openArchive(url: url)
            }
        }
    }

    @MainActor func saveButton() {
        // FIXME: Implement
    }

    @MainActor func extractButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Extract \(actualEntries.count) item\(actualEntries.count > 1 ? "s" : "")"
        if panel.runModal() == .OK {
            if let url = panel.url {
                Task {
                    await archive?.extractEntries(actualEntries, toFolder: url)
                }
            }
        }
    }

    @MainActor func renameButton(renameEntryFocus: FocusState<UUID?>.Binding, entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        renameEntryFocus.wrappedValue = actualEntries.first
    }

    @MainActor func deleteButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        archive?.removeEntries(actualEntries)
    }

    @MainActor func addButton() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            self.archive?.addEntries(from: panel.urls)
        }
    }

    func sort(using: [KeyPathComparator<ArchiveEntry>]) {
        self.archive?.sort(using: using)
    }

    @MainActor func extractForQuicklook() {
        quickLookItems = []
        Task {
            do {
                if let urls = try await archive?.extractEntriesToCache(selectedEntries) {
                    quickLookItems = urls
                    if quickLookItems.count > 0 {
                        quickLookURL = quickLookItems.first
                    }
                }
            } catch {
                #ZZError("Unable to extract items for quicklook: \(error)")
            }
        }
    }

    func doRename(of entry: ArchiveEntry) {
        self.archive?.processEntryRename(entry)
    }
}
