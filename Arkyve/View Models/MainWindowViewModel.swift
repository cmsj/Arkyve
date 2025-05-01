//
//  MainWindowViewModel.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import AppKit
import System
import UniformTypeIdentifiers

@Observable
@MainActor
class MainWindowViewModel {
    private(set) var archive: Archive? = nil

    var selectedEntries = Set<ArchiveEntry.ID>()
    var focusedEntry: UUID? = nil
    var quickLookURL: URL?
    var quickLookItems: [URL] = []
    var progress = 0.0
    var sortOrder = [KeyPathComparator(\ArchiveEntry.name)]

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
    // FIXME: If the archive's format is one we can't write, should we disable this?
    var disableSave: Bool { get { disableUI == true || archive?.dirty != true || archive?.format.canWrite == false || archive?.existsOnDisk == false }}
    var disableSaveAs: Bool { get { disableUI == true || archive == nil }}
    var disableQuicklook: Bool { get { disableUI == true || selectedEntries.isEmpty }}
    var disableExtract: Bool { get { disableUI == true || selectedEntries.isEmpty }}
    var disableRename: Bool { get { disableUI == true || selectedEntries.count != 1 }}
    var disableDelete: Bool { get { disableUI == true || selectedEntries.isEmpty }}
    var disableNewFolder: Bool { get { disableUI == true || archive == nil }}
    var disableUI: Bool = false

    // MARK: - Dynamic UI text
    let navTitleText = "Arkyve"
    var navSubtitleText: String {
        guard let archive else { return "" }
        return "\(archive.name) \(archive.dirty ? "(Unsaved)" : "")"
    }
    var statusBarText: String {
        guard let archive else { return "No archive open" }
        var text = "\(archive.entries.count) items"
        if !archive.format.canWrite { text += " (read-only)" }
        return text
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
    func newArchive() {
        showErrors.clear()

        archive = Archive()
        selectedEntries = []
        quickLookURL = nil
        quickLookItems = []
    }

    func openArchive(url: URL) async {
        showErrors.clear()

        let loader = libarchiveWrapper(url: url)
        self.disableUI = true
        defer { self.disableUI = false }

        do {
            try await withTaskProgression { _ in
                archive = try await loader.loadArchive()
                sort()
            } progress: { progression in
                Task { @MainActor in setProgress(progression) }
            }
        } catch {
            showErrors.err(.init(.openArchive, msg:error.localizedDescription))
        }
    }

    func closeArchive() {
        showErrors.clear()
        guard archive != nil else { return }

        archive = nil
        selectedEntries = []
        quickLookURL = nil
        quickLookItems = []
    }

    func saveArchive(to: URL, overrideFormat: libarchiveFormat = .Unknown, overrideFilters: [libarchiveFilter] = [.None]) async {
        guard let archive else { return }
        let loader = libarchiveWrapper(url: archive.URL)
        self.disableUI = true
        defer { self.disableUI = false }

        let (format, filters, headerMap) = archive.metadataForSaving(overrideFormat: overrideFormat, overrideFilters: overrideFilters)

        do {
            try await withTaskProgression(totalUnits: archive.entries.count) { _ in
                try await loader.writeArchive(headerMap: headerMap, to: to, format: format, filters: filters, skipRead: archive.isNew)

                archive.didSave(to: to)
            } progress: { progression in
                Task { @MainActor in setProgress(progression) }
            }
        } catch {
            showErrors.err(.init(.writeArchive, msg: error.localizedDescription))
        }
    }

    func copyArchive(to: URL) {
        guard let archive else { return }

        do {
            AKTrace("Copying \(archive.URL) to \(to)")
            try FileManager.default.copyItem(at: archive.URL, to: to)
            archive.didSave(to: to)
        } catch {
            showErrors.err(.init(.writeArchive, msg: error.localizedDescription))
        }
    }

    func extractForQuicklook() {
        guard let archive else { return }

        quickLookItems = []

        let chosenEntries = archive.entries.filter { selectedEntries.contains($0.id) }
        var extractableEntries: [ArchiveEntryExtractable] = []

        var itemCount = extractableEntries.count
        for entry in chosenEntries {
            switch entry.source.type {
            case .InMemory:
                continue
            case .Filesystem:
                // This is an entry that isn't in the archive yet, so we can skip marking it as extractable and just capture the URL
                quickLookItems.append(URL(filePath: entry.source.path))
            default:
                let extractableEntry = entry.asExtractable(for: archive)
                itemCount += extractableEntry.entries.count
                extractableEntries.append(extractableEntry)
            }
        }

        if extractableEntries.count == 0 && quickLookItems.count > 0 {
            // Nothing coming from the archive, but we have things coming from the filesystem
            quickLookURL = quickLookItems.first
        } else if extractableEntries.count > 0 {
            // At least something is coming from the archive, so process that and then show quicklook
            Task {
                do {
                    let loader = libarchiveWrapper(url: archive.URL)

                    try await withTaskProgression(totalUnits: itemCount) { _ in
                        quickLookItems += try await loader.extractEntries(extractableEntries, toFolder: archive.cacheURL)
                        quickLookURL = quickLookItems.first
                    } progress: { progression in
                        Task { @MainActor in setProgress(progression) }
                    }
                } catch let error as ArkyveError {
                    showErrors.err(error)
                } catch {
                    showErrors.err(.init(.unknown, msg: error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Button handlers
    func newButton() {
        if archive != nil && archive?.dirty == true {
            postSavePromptClosure = {
                self.newButton()
            }
            closeButton()
            return
        }

        newArchive()
    }

    func openButton() {
        if archive != nil && archive?.dirty == true {
            postSavePromptClosure = {
                self.openButton()
            }
            closeButton()
            return
        } else if archive != nil {
            closeButton()
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ArkyveFormats.utTypes

        if panel.runModal() == .OK {
            if let url = panel.url {
                Task { @MainActor in
                    await openArchive(url: url)
                }
            }
        }
    }

    func closeButton(force: Bool = false) {
        guard let archive else { return }

        if archive.dirty == true && !force {
            showSavePrompt = true
        } else {
            closeArchive()
        }
    }

    func revertButton() {
        guard let archive else { return }

        let url = archive.URL
        Task { @MainActor in
            await openArchive(url: url)
        }
    }

    func addButton() {
        guard let archive else { return }

        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.prompt = "Select files/folders to add"

        if panel.runModal() == .OK {
            do {
                try archive.addFiles(from: panel.urls)
                sort()
            } catch {
                showErrors.err(error)
            }
        }
    }

    func extractButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        guard let archive else { return }

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
            if let destURL = panel.url {
                let retainFullPath = button.state == .on
                var extractableEntries: [ArchiveEntryExtractable] = []
                let chosenEntries = archive.entries.filter { actualEntries.contains($0.id) }

                var itemCount = 0
                for entry in chosenEntries {
                    let extractableEntry = entry.asExtractable(for: archive)
                    itemCount += extractableEntry.entries.count
                    extractableEntries.append(extractableEntry)
                }

                Task {
                    let loader = libarchiveWrapper(url: archive.URL)
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
                    } catch let error as ArkyveError {
                        showErrors.err(error)
                    }
                }
            }
        }
    }

    func renameButton(entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        focusedEntry = actualEntries.first
    }

    func saveButton() {
        guard let archive = archive, archive.existsOnDisk != false else {
            // We're trying to save, but the archive has never been written to disk, so we need to do a Save As
            saveAsButton()
            return
        }

        Task {
            await saveArchive(to: archive.URL)
        }
    }

    func prepareSaveAsPanel() -> NSSavePanel {
        precondition(archive != nil, "prepareSavePanel called without ensuring archive exists")

        let panel = NSSavePanel()

        panel.prompt = "Save"
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = archive!.name.deletingPathExtension
        panel.allowedContentTypes = ArkyveFormats.writeableUTTypes
        panel.showsContentTypes = true

        let currentFormat = ArkyveFormats.initFromlibarchiveFormatForSaving(archive!.format, withFilters: archive!.filters)
        panel.currentContentType = currentFormat.utType

        return panel
    }

    func saveAsButton() {
        guard let archive = archive else { return }

        let panel = prepareSaveAsPanel()

        if panel.runModal() == .OK {
            if let destURL = panel.url {
                guard let selectedArkyveFormat = ArkyveFormats.initFromUTType(panel.currentContentType) else {
                    AKError("Unable to determine which archive format the user selected")
                    return
                }
                let selectedFormat = selectedArkyveFormat.libarchiveFormat
                let selectedFilters = selectedArkyveFormat.libarchiveFilters

                archive.name = destURL.lastPathComponent

                Task {
                    AKTrace("Save As to \(destURL) (format: \(selectedArkyveFormat))")

                    if !destURL.startAccessingSecurityScopedResource() {
                        AKError("Unable to access security scope for \(destURL)")
                        return
                    }
                    defer { destURL.stopAccessingSecurityScopedResource() }

                    if !archive.dirty && archive.format == selectedFormat && archive.filters == selectedFilters {
                        // This is a performance optimisation
                        // The archive/format/filters haven't changed, so just copy the existing file
                        copyArchive(to: destURL)
                    } else {
                        archive.format = selectedFormat
                        archive.filters = selectedFilters
                        await saveArchive(to: destURL)
                    }
                }
            }
        }
    }

    func deleteButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        guard let archive else { return }

        let actualEntries = entries ?? selectedEntries
        archive.removeEntries(actualEntries)

        // Curiously, the selection binding doesn't clear automatically when we remove items from the table
        selectedEntries.removeAll()
    }

    func newFolderButton(entries: Set<ArchiveEntry.ID>? = nil) {
        guard let archive else { return }

        let actualEntries = entries ?? selectedEntries
        var parentEntryID: UUID = archive.root.id

        // See if we can be more specific than the root entry being the parent
        if actualEntries.first != nil {
            if let tmpParentEntry = archive.entryForID(actualEntries.first!) {
                if tmpParentEntry.type == .directory {
                    // We have a selected entry and it's a directory, we can parent directly to it
                    parentEntryID = actualEntries.first!
                } else {
                    // We have a selected entry, but it's not a directory, so let's find its parent
                    if let tmpGrandParentEntry = archive.parentForEntry(tmpParentEntry) {
                        parentEntryID = tmpGrandParentEntry.id
                    }
                }
            }
        }

        if let newFolderID = archive.newFolder(at: parentEntryID) {
            Task { @MainActor in
                selectedEntries = [newFolderID]
                archive.entryForID(parentEntryID)?.isExpanded = true

                Task { @MainActor in
                    focusedEntry = newFolderID
                }
            }
        }
    }

    // MARK: - Other handlers
    func doRename(of entry: ArchiveEntry) {
        guard let archive else { return }

        archive.processEntryRename(entry)
        sort()
    }

    func sort() {
        guard let archive else { return }

        archive.sort(using: sortOrder)
    }

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
