//
//  MainWindowViewModel.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import AppKit
import System
import ZZLog

@Observable
@MainActor
class MainWindowViewModel {
    private(set) var loader: libarchive? = nil
    private(set) var archive: Archive? = nil

    var selectedEntries = Set<ArchiveEntry.ID>()
    var quickLookURL: URL?
    var quickLookItems: [URL] = []

    @MainActor
    var showErrors: ShowErrors = ShowErrors()

    var disableRevert: Bool {
        get {
            archive?.dirty != true || archive?.existsOnDisk != true
        }
    }
    var disableClose: Bool {
        get {
            archive == nil
        }
    }
    var disableSave: Bool {
        get {
            archive?.dirty != true
        }
    }
    var disableSaveAs: Bool {
        get {
            archive == nil
        }
    }
    var disableQuicklook: Bool {
        get {
            selectedEntries.isEmpty
        }
    }
    var disableExtract: Bool {
        get {
            selectedEntries.isEmpty
        }
    }
    var disableRename: Bool {
        get {
            selectedEntries.count != 1
        }
    }
    var disableDelete: Bool {
        get {
            selectedEntries.isEmpty
        }
    }

    func openArchive(url: URL) async {
        loader = libarchive(url: url)
        do {
            archive = try await loader?.loadArchive()
        } catch {
            showErrors.err(ArchiveError.ArchiveOpenError(archive: url.path, error: error.localizedDescription))
        }
    }

    func saveArchive(to: URL) async {
        guard let archive = archive else { return }
        loader = libarchive(url: archive.URL)

        let headerMap = archive.entries.reduce(into: [String:ArchiveEntryFlat]()) {
            $0[$1.path] = $1.flatSelf()
        }
        do {
            try await loader?.writeArchive(headerMap: headerMap, to: archive.URL, format: archive.format, filters: archive.filters)
        } catch {
            showErrors.err(ArchiveError.ArchiveWriteError(archive: "\(String(describing: URL.path)) -> \(to.path)", error: error.localizedDescription))
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

    @MainActor func closeButton() {
        archive = nil
        selectedEntries = []
        quickLookURL = nil
        quickLookItems = []
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
                    let extractableEntry = ArchiveEntryExtractable(showErrors: showErrors,
                                                                   archiveURL: archive?.URL,
                                                                   cacheURL: archive?.cacheURL,
                                                                   selectedPath: entry.path,
                                                                   id: entry.id,
                                                                   entries: entry.flatChildren())
                    extractableEntries.append(extractableEntry)
                }

                Task {
                    let loader = libarchive(url: archiveURL)

                    do {
                        let _ = try await loader.extractEntries(extractableEntries, toFolder: destURL, retainFullPath: retainFullPath)
                    } catch let error as ArchiveError {
                        showErrors.err(error)
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
                let extractableEntry = ArchiveEntryExtractable(showErrors: showErrors,
                                                               archiveURL: archive?.URL,
                                                               cacheURL: archive?.cacheURL,
                                                               selectedPath: entry.path,
                                                               id: entry.id,
                                                               entries: entry.flatChildren())
                extractableEntries.append(extractableEntry)
            }

            do {
                let writtenURLs = try await loader.extractEntries(extractableEntries, toFolder: cacheURL)
                if writtenURLs.count > 0 {
                    quickLookItems = writtenURLs
                    quickLookURL = writtenURLs.first
                }
            } catch let error as ArchiveError {
                showErrors.err(error)
            } catch {
                showErrors.err(ArchiveError.ArchiveUnknownError(msg: error.localizedDescription))
            }
        }
    }

    @MainActor func newButton() {
        archive = Archive()
        selectedEntries = []
        quickLookURL = nil
        quickLookItems = []
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

    @MainActor func renameButton(renameEntryFocus: FocusState<UUID?>.Binding, entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        renameEntryFocus.wrappedValue = actualEntries.first
    }

    @MainActor func saveButton() {
        Task { @MainActor in
            await saveArchive(to: URL(filePath:"/Users/cmsj/Downloads/lol.zip"))
        }
    }

    @MainActor func saveAsButton() {
        // TODO: WRITE
    }

    // TODO: WRITE
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
    func doRename(of entry: ArchiveEntry) {
//        self.archive?.processEntryRename(entry)
        self.archive?.dirty = true
    }
}
