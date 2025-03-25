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
    var disableSaveAs: Bool { get { disableSave }}
    var disableQuicklook: Bool { get { disableUI == true || selectedEntries.isEmpty }}
    var disableExtract: Bool { get { disableUI == true || selectedEntries.isEmpty }}
    var disableRename: Bool { get { disableUI == true || selectedEntries.count != 1 }}
    var disableDelete: Bool { get { disableUI == true || selectedEntries.isEmpty }}
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

    func saveArchive(to: URL, overrideFormat: libarchiveFormat = .Unknown, overrideFilter: libarchiveFilter = .None) async {
        guard let archive = archive else { return }
        let loader = libarchiveWrapper(url: archive.URL)
        self.disableUI = true
        defer { self.disableUI = false }

        let format = overrideFormat == .Unknown ? archive.format : overrideFormat
        let filters = overrideFilter == .None ? archive.filters : [overrideFilter, .None]

        let headerMap = archive.entries.reduce(into: [String:ArchiveEntryFlat]()) {
            $0[$1.path] = $1.flatSelf()
        }
        do {
            try await withTaskProgression { _ in
                try await loader.writeArchive(headerMap: headerMap, to: to, format: format, filters: filters)
                archive.setDirty(false)
            } progress: { progression in
                Task { @MainActor in setProgress(progression) }
            }
        } catch {
            showErrors.err(ArchiveError.ArchiveWriteError(archive: "\(String(describing: URL.path)) -> \(to.path)", error: error.localizedDescription))
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
                let extractableEntry = entry.asExtractable(for: archive)
                itemCount += extractableEntry.entries.count
                extractableEntries.append(extractableEntry)
            }

            do {
                try await withTaskProgression(totalUnits: itemCount) { _ in
                    let writtenURLs = try await loader.extractEntries(extractableEntries, toFolder: cacheURL)
                    if writtenURLs.count > 0 {
                        quickLookItems = writtenURLs
                        quickLookURL = writtenURLs.first
                    }                } progress: { progression in
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
        panel.allowedContentTypes = [.archive]

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

        // FIXME: Refactor some of this out into an extraction method
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
                            let _ = try await loader.extractEntries(extractableEntries, toFolder: destURL, retainFullPath: retainFullPath)
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

        panel.prompt = "Save"
        panel.isExtensionHidden = false

        let viewModel = FormatPickerViewModel()

        if archive.format != .Unknown {
            viewModel.format = archive.format
        }
        if archive.format == .TAR || archive.format == .TAR_GNUTAR {
            viewModel.filter = archive.filters.first ?? .GZip
        }

        let accessoryViewHosted = FormatPicker().environment(\.formatPickerViewModel, viewModel)
        let hostingController = NSHostingController(rootView: accessoryViewHosted)
        panel.accessoryView = hostingController.view

        if panel.runModal() == .OK {
            if let destURL = panel.url {
                archive.name = destURL.lastPathComponent
                Task {
                    #ZZTrace("Save As to \(destURL) (format: \(viewModel.format) \(viewModel.filter))")
                    await saveArchive(to: destURL, overrideFormat: viewModel.format, overrideFilter: viewModel.filter)
                }
            }
        }
    }

    func deleteButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        // TODO: WRITE
        self.archive?.setDirty()
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
                            self.handleEntryDrop(at: index, on: destUUID, entry: entry)
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

    func handleEntryDrop(at index: Int? = nil, on entryID: UUID? = nil, entry: ArchiveEntryExtractable) {
        print("HANDLING ENTRY DROPPED AT \(index ?? -1) on \(entryID?.uuidString ?? "unknown"): \(entry)")
        
        guard let archive = archive else { return }
        
        // 1. Find the current parent by looking up the entry in the archive's entries
        let currentEntry = archive.entries.first { $0.id == entry.id }
        guard let currentEntry = currentEntry else { return }
        
        // 2. Find the new parent
        let newParent: ArchiveEntry
        if let entryID = entryID {
            // If we have an entryID, find that entry in the archive
            guard let parent = archive.entries.first(where: { $0.id == entryID }) else { return }
            newParent = parent
        } else {
            // If no entryID, use the root
            newParent = archive.root
        }
        
        // 3. Remove from current parent
        func removeFromParent(_ entry: ArchiveEntry) {
            // Find the parent in the archive's entries
            if let parent = archive.entries.first(where: { parent in
                parent.children?.contains(where: { $0.id == entry.id }) ?? false
            }) {
                parent.children?.removeAll { $0.id == entry.id }
            }
        }
        removeFromParent(currentEntry)
        
        // 4. Update pathComponents to the new parent + name
        let newPathComponents = newParent.pathComponents + [currentEntry.name]
        currentEntry.pathComponents = newPathComponents
        currentEntry.path = newPathComponents.joined(separator: "/")
        
        // 5. Add to new parent
        newParent.children?.append(currentEntry)
        
        // 6. Update path and pathComponents in Archive.entries (ie the flat list)
        // The entry in Archive.entries is already updated since we modified the same object
        
        // Mark the archive as dirty since we've made changes
        archive.setDirty()
    }

    func handleFileURLDrop(at index: Int? = nil, on entryID: UUID? = nil, fileURL: URL) {
        print("HANDLING FILEURL DROPPED AT \(index ?? -1) on \(entryID?.uuidString ?? "unknown"): \(fileURL)")
        
        guard let archive = archive else { return }
        
        // 1. Find the new parent
        let newParent: ArchiveEntry
        if let entryID = entryID {
            // If we have an entryID, find that entry in the archive
            guard let parent = archive.entries.first(where: { $0.id == entryID }) else { return }
            newParent = parent
        } else {
            // If no entryID, use the root
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
            case .entry(let entry):
                handleEntryDrop(on: entryID, entry: entry)
            case .file(let url):
                handleFileURLDrop(on: entryID, fileURL: url)
            default:
                showErrors.err(ArchiveError.ArchiveDropError(msg: "Unknown drop type"))
            }
        }

    }
}
