//
//  MainWindowViewModel.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import AppKit
import System
import UniformTypeIdentifiers
import ZZLog

@Observable
@MainActor
class MainWindowViewModel {
    private(set) var archive: Archive? = nil

    var selectedEntries = Set<ArchiveEntry.ID>()
    var quickLookURL: URL?
    var quickLookItems: [URL] = []
    var progress = 0.0

    var showErrors: ShowErrors = ShowErrors()

    // MARK: - Save prompt
    var showSavePrompt = false
    var postSavePromptClosure: (() -> Void)? = nil

    // MARK: - Disable various parts of the UI
    var disableNew: Bool { get { disableUI == true }}
    var disableOpen: Bool { get { disableUI == true }}
    var disableAdd: Bool { get { disableUI == true || archive == nil }}
    var disableRevert: Bool { get { disableUI == true || archive?.dirty != true || archive?.existsOnDisk != true }}
    var disableClose: Bool { get { disableUI == true || archive == nil }}
    var disableSave: Bool { get { disableUI == true || archive?.dirty != true }}
    var disableSaveAs: Bool { get { disableUI == true || archive == nil }}
    var disableQuicklook: Bool { get { disableUI == true || selectedEntries.isEmpty }}
    var disableExtract: Bool { get { disableUI == true || selectedEntries.isEmpty }}
    var disableRename: Bool { get { disableUI == true || selectedEntries.count != 1 }}
    var disableDelete: Bool { get { disableUI == true || selectedEntries.isEmpty }}
    var disableNewFolder: Bool { get { disableUI == true || archive == nil }}
    var disableUI: Bool = false

    // MARK: - Dynamic UI text
    var statusBarText: String {
        guard let archive else { return "No archive open" }
        return "\(archive.entries.count) items"
    }

    var navSubtitleText: String {
        guard let archive else { return "" }
        return "\(archive.name) \(archive.dirty ? "(Unsaved)" : "")"
    }

    // MARK: - Progress indicator
    func setProgress(_ tp: TaskProgress) {
        switch tp.status {
        case .running(let units):
            if let total = units.total {
                progress = Double(units.completed) / Double(total)
            } else {
                progress = 1.0
            }
        case .finished, .failed(_): progress = 0.0
        }
    }

    // MARK: - Archive operations

    func openArchive(url: URL) async {
        let loader = libarchiveWrapper(url: url)
        self.disableUI = true
        defer { self.disableUI = false }

        do {
            try await withTaskProgression { _ in
                archive = try await loader.loadArchive()
            } progress: { progression in
                Task { @MainActor in setProgress(progression) }
            }
        } catch {
            showErrors.err(ArchiveError.ArchiveOpenError(archive: url.path, error: error.localizedDescription))
        }
    }

    func closeArchive() {
        guard archive != nil else { return }

        archive = nil
        selectedEntries = []
        quickLookURL = nil
        quickLookItems = []

        showErrors.clear()
    }

    func saveArchive(to: URL, overrideFormat: libarchiveFormat = .Unknown, overrideFilters: [libarchiveFilter] = [.None]) async {
        guard let archive = archive else { return }
        let loader = libarchiveWrapper(url: archive.URL)
        self.disableUI = true
        defer { self.disableUI = false }

        let format = overrideFormat == .Unknown ? archive.format : overrideFormat
        let filters = overrideFilters == [.None] ? archive.filters : overrideFilters

        let headerMap = archive.entries.reduce(into: [String:ArchiveEntryFlat]()) { map, entry in
            if entry.type == .root { return }
            map[entry.path] = entry.flatSelf()
        }
        do {
            try await withTaskProgression(totalUnits: archive.entries.count) { _ in
                try await loader.writeArchive(headerMap: headerMap, to: to, format: format, filters: filters, skipRead: archive.isNew)

                // Having written the archive, we should no longer have any entries of source type .Filesystem
                // So we'll update our entries to switch them to .Archive
                // Same for .InMemory directories
                archive.entries.forEach { entry in
                    if (entry.source.type == .Filesystem || entry.source.type == .InMemory) {
                        entry.source = .init(type: .Archive, path: entry.path)
                    }
                }

                archive.setClean()
                archive.isNew = false
            } progress: { progression in
                Task { @MainActor in setProgress(progression) }
            }
        } catch {
            showErrors.err(ArchiveError.ArchiveWriteError(archive: archive.name, error: error.localizedDescription))
        }
    }

    func copyArchive(to: URL) {
        guard let archive else { return }

        do {
            try FileManager.default.copyItem(at: archive.URL, to: to)
        } catch {
            showErrors.err(ArchiveError.ArchiveWriteError(archive: archive.name, error: error.localizedDescription))
        }
    }

    func extractForQuicklook() {
        quickLookItems = []
        guard let archiveURL = archive?.URL else { return }
        guard let cacheURL = archive?.cacheURL else { return }

        Task {
            let loader = libarchiveWrapper(url: archiveURL)
            let chosenEntries = archive?.entries.filter { selectedEntries.contains($0.id) } ?? []
            var extractableEntries: [ArchiveEntryExtractable] = []

            var itemCount = extractableEntries.count
            for entry in chosenEntries {
                if entry.source.type == .Filesystem {
                    // This is an entry that isn't in the archive yet, so we can skip marking it as extractable and just capture the URL
                    quickLookItems.append(URL(filePath: entry.source.path))
                } else {
                    let extractableEntry = entry.asExtractable(for: archive)
                    itemCount += extractableEntry.entries.count
                    extractableEntries.append(extractableEntry)
                }
            }

            do {
                try await withTaskProgression(totalUnits: itemCount) { _ in
                    quickLookItems += try await loader.extractEntries(extractableEntries, toFolder: cacheURL)
                    quickLookURL = quickLookItems.first
                } progress: { progression in
                    Task { @MainActor in setProgress(progression) }
                }
            } catch let error as ArchiveError {
                showErrors.err(error)
            } catch {
                showErrors.err(ArchiveError.ArchiveUnknownError(msg: error.localizedDescription))
            }
        }
    }

    // MARK: - Button handlers
    func openButton() {
        if archive != nil && archive?.dirty == true {
            postSavePromptClosure = {
                self.openButton()
            }
            closeButton()
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.archive] // FIXME: Do better content type handling

        if panel.runModal() == .OK {
            if let url = panel.url {
                Task { @MainActor in
                    await openArchive(url: url)
                }
            }
        }
    }

    func closeButton(force: Bool = false) {
        if archive?.dirty == true && !force {
            showSavePrompt = true
        } else {
            closeArchive()
        }
    }

    func addButton() {
        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.prompt = "Select files/folders to add"

        if panel.runModal() == .OK {
            let pwd = panel.urls.first?.deletingLastPathComponent()
            do {
                try archive?.addFiles(from: panel.urls, pwd: pwd)
            } catch {
                showErrors.err(error)
            }
        }
    }

    func extractButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
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

        // FIXME: Refactor some of this out into an extraction method?
        if panel.runModal() == .OK {
            if let destURL = panel.url, let archiveURL = archive?.URL {
                let retainFullPath = button.state == .on
                var extractableEntries: [ArchiveEntryExtractable] = []
                let chosenEntries = archive?.entries.filter { actualEntries.contains($0.id) } ?? []

                var itemCount = 0
                for entry in chosenEntries {
                    let extractableEntry = entry.asExtractable(for: archive)
                    itemCount += extractableEntry.entries.count
                    extractableEntries.append(extractableEntry)
                }

                Task {
                    let loader = libarchiveWrapper(url: archiveURL)
                    self.disableUI = true
                    defer { self.disableUI = false }

                    do {
                        try await withTaskProgression(totalUnits: itemCount) { _ in
                            let _ = try await loader.extractEntries(extractableEntries,
                                                                    toFolder: destURL,
                                                                    retainFullPath: retainFullPath)
                        } progress: { progression in
                            Task { @MainActor in setProgress(progression) }
                        }
                    } catch let error as ArchiveError {
                        showErrors.err(error)
                    }
                }
            }
        }
    }

    func newButton() {
        if archive != nil && archive?.dirty == true {
            postSavePromptClosure = {
                self.newButton()
            }
            closeButton()
            return
        }

        archive = Archive()
        selectedEntries = []
        quickLookURL = nil
        quickLookItems = []
    }

    func revertButton() {
        guard archive != nil else { return }
        if let url = archive?.URL {
            Task { @MainActor in
                await openArchive(url: url)
            }
        }
    }

    func renameButton(renameEntryFocus: FocusState<UUID?>.Binding, entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        renameEntryFocus.wrappedValue = actualEntries.first
    }

    func saveButton() {
        guard let archive = archive, archive.existsOnDisk != false else {
            // We're trying to save, but the archive has never been written to disk, so we need to do a Save As
            saveAsButton()
            return
        }

        Task { @MainActor in
            await saveArchive(to: archive.URL)
        }
    }

    func saveAsButton() {
        guard let archive = archive else { return }

        let panel = NSSavePanel()
        let viewModel = FormatPickerViewModel(panel: panel)

        if archive.format != .Unknown {
            viewModel.format = archive.format
        }

        panel.prompt = "Save"
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = archive.name.deletingPathExtension

        let accessoryViewHosted = FormatPicker().environment(\.formatPickerViewModel, viewModel)
        let hostingController = NSHostingController(rootView: accessoryViewHosted)
        panel.accessoryView = hostingController.view

        if panel.runModal() == .OK {
            if let destURL = panel.url {
                archive.name = destURL.lastPathComponent
                Task {
                    #ZZTrace("Save As to \(destURL) (format: \(viewModel.format))")

                    if !archive.dirty && archive.format == viewModel.format {
                        // This is a performance optimisation
                        // The archive/format/filters haven't changed, so just copy the existing file
                        copyArchive(to: destURL)
                    } else {
                        archive.format = viewModel.format
                        archive.filters = viewModel.format.defaultFilters
                        await saveArchive(to: destURL)
                    }
                }
            }
        }
    }

    func deleteButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        self.archive?.removeEntries(actualEntries)

        // Curiously, the selection binding doesn't clear automatically when we remove items from the table
        selectedEntries.removeAll()
    }

    func newFolderButton(renameEntryFocus: FocusState<UUID?>.Binding, entries: Set<ArchiveEntry.ID>? = nil) {
        guard archive != nil else { return }

        let actualEntries = entries ?? selectedEntries
        var parentEntryID: UUID = archive!.root.id

        // See if we can be more specific than the root entry being the parent
        if actualEntries.first != nil {
            if let tmpParentEntry = archive?.entryForID(actualEntries.first!) {
                if tmpParentEntry.type == .directory {
                    // We have a selected entry and it's a directory, we can parent directly to it
                    parentEntryID = actualEntries.first!
                } else {
                    // We have a selected entry, but it's not a directory, so let's find its parent
                    if let tmpGrandParentEntry = archive?.parentForEntry(tmpParentEntry) {
                        parentEntryID = tmpGrandParentEntry.id
                    }
                }
            }
        }

        if let newFolderID = self.archive?.newFolder(at: parentEntryID) {
            Task { @MainActor in
                selectedEntries = [newFolderID]
                Task { @MainActor in
                    renameEntryFocus.wrappedValue = newFolderID
                }
            }
        }
    }

    // MARK: - Other handlers
    func doRename(of entry: ArchiveEntry) {
        self.archive?.processEntryRename(entry)
    }

    func sort(using: [KeyPathComparator<ArchiveEntry>]) {
        self.archive?.sort(using: using)
    }

    // MARK: - Drag and drop
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
                            let error = ArchiveError.ArchiveDropError(msg: "Failed to handle drop: \(error.localizedDescription)")
                            self.showErrors.err(error)
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
                            let error = ArchiveError.ArchiveDropError(msg: "Failed to handle drop: \(error.localizedDescription)")
                                self.showErrors.err(error)
                        }
                    }
                }
            } else {
                showErrors.err(ArchiveError.ArchiveDropError(msg: "Unsupported item type: \(provider.registeredTypeIdentifiers.joined(separator: ","))"))
            }
        }
    }

    func handleEntryDrop(at index: Int? = nil, on entryID: UUID? = nil, entryExtractable: ArchiveEntryExtractable) {
        print("HANDLING ENTRY DROPPED AT \(index ?? -1) on \(entryID?.uuidString ?? "unknown"): \(entryExtractable)")

        guard let archive = archive else { return }
        // 1. Find the current entry from the supplied extractable
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

        archive.reparentEntry(entry, to: newParent)
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
            try archive.addFiles(from: [fileURL], pwd: fileURL.deletingLastPathComponent(), parent: newParent)
        } catch {
            showErrors.err(error)
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
                showErrors.err(ArchiveError.ArchiveDropError(msg: "Unknown drop type"))
            }
        }

    }
}
