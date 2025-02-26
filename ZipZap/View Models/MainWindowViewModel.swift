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
        let loader = libarchive(url: url)
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
        let loader = libarchive(url: archive.URL)
        self.disableUI = true
        defer { self.disableUI = false }

        let format = overrideFormat == .Unknown ? archive.format : overrideFormat
        let filters = overrideFilter == .None ? archive.filters : [overrideFilter, .None]

        let headerMap = archive.entries.reduce(into: [String:ArchiveEntryFlat]()) {
            $0[$1.path] = $1.flatSelf()
        }
        do {
            try await withTaskProgression { _ in
                try await loader.writeArchive(headerMap: headerMap, to: archive.URL, format: format, filters: filters)
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
            let loader = libarchive(url: archiveURL)
            let chosenEntries = archive?.entries.filter { selectedEntries.contains($0.id) } ?? []
            var extractableEntries: [ArchiveEntryExtractable] = []

            var itemCount = extractableEntries.count
            for entry in chosenEntries {
                let flatChildren = entry.flatChildren()
                itemCount += flatChildren.count
                let extractableEntry = ArchiveEntryExtractable(showErrors: showErrors,
                                                               archiveURL: archive?.URL,
                                                               cacheURL: archive?.cacheURL,
                                                               selectedPath: entry.path,
                                                               id: entry.id,
                                                               entries: flatChildren)
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
                    let flatChildren = entry.flatChildren()
                    itemCount += flatChildren.count

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
            archive = nil
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
        guard archive?.existsOnDisk != false else {
            // We're trying to save, but the archive has never been written to disk, so we need to do a Save As
            saveAsButton()
            return
        }

        Task { @MainActor in
            // FIXME: This obviously should save over the original archive
            await saveArchive(to: URL(filePath:"/Users/cmsj/Downloads/lol.zip"))
        }
    }

    func saveAsButton() {
        let panel = NSSavePanel()

        panel.prompt = "Save"
        panel.isExtensionHidden = false

        let viewModel = FormatPickerViewModel()

        if archive?.format != .Unknown {
            viewModel.format = archive!.format
        }
        if archive?.format == .TAR || archive?.format == .TAR_GNUTAR {
            viewModel.filter = archive?.filters.first ?? .GZip
        }

        let accessoryViewHosted = FormatPicker().environment(\.formatPickerViewModel, viewModel)
        let hostingController = NSHostingController(rootView: accessoryViewHosted)
        panel.accessoryView = hostingController.view

        if panel.runModal() == .OK {
            if let destURL = panel.url {
                Task {
                    print("User chose format: \(viewModel.format) \(viewModel.filter)")
                    await saveArchive(to: destURL, overrideFormat: viewModel.format, overrideFilter: viewModel.filter)
                }
            }
        }
    }

    func deleteButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        // TODO: WRITE
        self.archive?.setDirty()
    }
//
//    func addButton() {
//        let panel = NSOpenPanel()
//        panel.allowsMultipleSelection = false
//        panel.canChooseDirectories = false
//        if panel.runModal() == .OK {
//            self.archive?.addEntries(from: panel.urls)
//        }
//    }

    // MARK: - Other handlers
// TODO: WRITE
    func doRename(of entry: ArchiveEntry) {
//        self.archive?.processEntryRename(entry)
        self.archive?.setDirty()
    }

    func sort(using: [KeyPathComparator<ArchiveEntry>]) {
        self.archive?.sort(using: using)
    }

    // MARK: - Drag and drop
    func processDrop(at index: Int, on entry: ArchiveEntry?, for providers: [NSItemProvider]) {
        let (internals, externals) = providers.filterBothwise { $0.hasItemConformingToTypeIdentifier(ArchiveEntry.draggableType.identifier) }

        if internals.count > 0 {
            processDropInternal(at: index, on: entry, for: internals)
        }
        if externals.count > 0 {
            processDropExternal(at: index, on: entry, for: externals)
        }
    }

    func processDropInternal(at index: Int, on entry: ArchiveEntry?, for providers: [NSItemProvider]) {
        #ZZTrace("Processing internal drop")

        let decoder = JSONDecoder()

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(ArchiveEntry.draggableType.identifier) else { continue }

            _ = provider.loadDataRepresentation(for: ArchiveEntry.draggableType) { [weak self] data, error in
                guard let self = self else { return }
                guard let data = data else {
                    let error = ArchiveError.ArchiveDropError(msg: "Failed to load data from provider: \(error?.localizedDescription ?? "Unknown error")")
                    Task { @MainActor in
                        self.showErrors.err(error)
                    }
                    return
                }

                let id = try? decoder.decode(UUID.self, from: data)

                // FIXME: What now?
                print("Dragged item ID: \(id?.uuidString ?? "unknown")")
            }
        }
    }

    func processDropExternal(at index: Int, on entry: ArchiveEntry?, for providers: [NSItemProvider]) {
        #ZZTrace("Processing external drop")

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }

            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] (urlData, error) in
                guard let self = self else { return }

                if let urlData = urlData as? Data,
                    let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    #ZZTrace("Processing external drop for file: \(url.path)")

                    // FIXME: What now?
                } else if let error = error {
                    let error = ArchiveError.ArchiveDropError(msg: "Failed to load URL from provider: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.showErrors.err(error)
                    }
                }
            }
        }
    }
}
