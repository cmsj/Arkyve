//
//  MainWindowViewModel.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import AppKit
import ZZLog

@Observable
class MainWindowViewModel {
    private(set) var loader: libarchive? = nil
    private(set) var archive: Archive? = nil

    var selectedEntries = Set<ArchiveEntry.ID>()
    var quickLookURL: URL?
    var quickLookItems: [URL] = []

    func openArchive(url: URL) async {
        loader = libarchive(url: url)
        do {
            archive = try await loader?.readArchive()
        } catch {
            let error = error.localizedDescription
            #ZZError("Error loading archive: \(error)")
        }
    }

    @MainActor func openButton() {
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

    @MainActor func extractButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        let panel = NSOpenPanel()

        let button = NSButton.init()
        button.setButtonType(.switch)
        button.title = "Retain full archive path"
        button.state = .off

        panel.accessoryView = button

        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Extract \(actualEntries.count) item\(actualEntries.count > 1 ? "s" : "")"

        if panel.runModal() == .OK {
            if let destURL = panel.url, let archiveURL = archive?.URL {
                let retainFullPath = button.state == .on
                var extractableEntries: [ArchiveEntryExtractable] = []
                let chosenEntries = archive?.entries.filter { actualEntries.contains($0.id) } ?? []

                for entry in chosenEntries {
                    let extractableEntry = ArchiveEntryExtractable(archiveURL: archive?.URL,
                                                                   cacheURL: archive?.cacheURL,
                                                                   selectedPath: entry.path,
                                                                   entries: entry.flatChildren())
                    extractableEntries.append(extractableEntry)
                }

                Task {
                    let loader = libarchive(url: archiveURL)

                    do {
                        let _ = try await loader.extractEntries(extractableEntries, toFolder: destURL, retainFullPath: retainFullPath)
                    } catch {
                        let error = "Writing failed for \(chosenEntries.first?.path ?? "Unknown"): \(error)"
                        #ZZError(error)
                    }
                }
            }
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
            var extractableEntries: [ArchiveEntryExtractable] = []

            for entry in chosenEntries {
                let extractableEntry = ArchiveEntryExtractable(archiveURL: archive?.URL,
                                                               cacheURL: archive?.cacheURL,
                                                               selectedPath: entry.path,
                                                               entries: entry.flatChildren())
                extractableEntries.append(extractableEntry)
            }

            do {
                let writtenURLs = try await loader.extractEntries(extractableEntries, toFolder: cacheURL)
                if writtenURLs.count > 0 {
                    quickLookItems = writtenURLs
                    quickLookURL = writtenURLs.first
                }
            } catch {
                let error = "Quick failed for \(chosenEntries.first?.path ?? "Unknown"): \(error)"
                #ZZError(error)
            }
        }
    }

// TODO: WRITE
//    var newFolderURL: URL {
//        get {
//            UserDefaults.standard.url(forKey: "newFolderURL") ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
//        }
//        set(url) {
//            UserDefaults.standard.setValue(url, forKey: "newFolderURL")
//        }
//    }

// TODO: WRITE
//    @MainActor func newButton() {
//        archive = Archive(URL: URL(fileURLWithPath: "/___UNKNOWN"))
//    }

// TODO: WRITE
//    @MainActor func revertButton() {
//        guard archive != nil else { return }
//        if let url = archive?.URL {
//            archive = nil
//            Task { @MainActor in
//                await openArchive(url: url)
//            }
//        }
//    }

//    @MainActor func saveButton() {
//        // FIXME: Implement
//    }

// TODO: WRITE
//    @MainActor func renameButton(renameEntryFocus: FocusState<UUID?>.Binding, entries: Set<ArchiveEntry.ID>? = nil) {
//        let actualEntries = entries ?? selectedEntries
//        renameEntryFocus.wrappedValue = actualEntries.first
//    }
//
//    @MainActor func deleteButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
//        let actualEntries = entries ?? selectedEntries
//        archive?.removeEntries(actualEntries)
//    }
//
//    @MainActor func addButton() {
//        let panel = NSOpenPanel()
//        panel.allowsMultipleSelection = false
//        panel.canChooseDirectories = false
//        if panel.runModal() == .OK {
//            self.archive?.addEntries(from: panel.urls)
//        }
//    }

// TODO: WRITE
//    func doRename(of entry: ArchiveEntry) {
//        self.archive?.processEntryRename(entry)
//    }
}
