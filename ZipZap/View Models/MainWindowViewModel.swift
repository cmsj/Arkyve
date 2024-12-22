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
    private(set) var loader: libarchive? = nil
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
        loader = libarchive(url: url)
        do {
            archive = try await loader?.readArchive()
        } catch {
            let error = error.localizedDescription
            #ZZError("Error loading archive: \(error)")
        }
    }

    @MainActor func newButton() {
        archive = Archive(URL: URL(fileURLWithPath: "/___UNKNOWN"))
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
            if let destURL = panel.url, let archiveURL = archive?.URL {
                Task {
                    let loader = libarchive(url: archiveURL)
                    let chosenEntries = archive?.entries.filter { actualEntries.contains($0.id) } ?? []
                    let paths = chosenEntries.map { $0.path }

                    do {
                        let _ = try await loader.extractEntries(paths, toFolder: destURL)
                    } catch {
                        let error = "Writing failed for \(paths.first ?? "Unknown"): \(error)"
                        #ZZError(error)
                    }
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

    @MainActor
    func sort(using: [KeyPathComparator<ArchiveEntry>]) {
        self.archive?.sort(using: using)
    }

    @MainActor func extractForQuicklook() {
        quickLookItems = []
        guard let archiveURL = archive?.URL else { return }
        guard let cacheURL = archive?.cacheURL else { return }

        Task {
            let loader = libarchive(url: archiveURL)
            let chosenEntries = archive?.entries.filter { selectedEntries.contains($0.id) } ?? []
            let paths = chosenEntries.map { $0.path }

            do {
                let writtenURLs = try await loader.extractEntries(paths, toFolder: cacheURL)
                if writtenURLs.count > 0 {
                    quickLookURL = writtenURLs.first
                }
            } catch {
                let error = "Quick failed for \(paths.first ?? "Unknown"): \(error)"
                #ZZError(error)
            }
        }
    }

// TODO: WRITE
//    func doRename(of entry: ArchiveEntry) {
//        self.archive?.processEntryRename(entry)
//    }
}
