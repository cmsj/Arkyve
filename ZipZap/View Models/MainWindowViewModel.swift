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
        set(url) { UserDefaults.standard.setValue(url, forKey: "newFolderURL") }
    }

    func openArchive(url: URL) {
        let name = url.lastPathComponent
        archive = Archive(name: name, URL: url)
        archive?.open()
    }

    @MainActor func openButton() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            if let url = panel.url {
                openArchive(url: url)
            }
        }
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
                    archive?.extractEntries(actualEntries, toFolder: url)
                }
            }
        }
    }

    @MainActor func renameButton(renameEntry: FocusState<UUID?>.Binding, entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        renameEntry.wrappedValue = actualEntries.first
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
        // FIXME: entry.name has updated, but entry.path and entry.pathComponents haven't.
        // We've never before had to think about any of these changing, and it seems weird that we have all three.
        // Maybe rename entry.path to entry.libarchivePath, never change it, and make entry.name a computed property
        // that works on entry.pathComponents' last value?
        print("NAME CHANGED: \(entry.name) :: \(entry.path) :: \(entry.pathComponents)")
    }
}
