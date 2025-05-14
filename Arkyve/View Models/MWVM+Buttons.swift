//
//  MWVM+Buttons.swift
//  Arkyve
//
//  Created by Chris Jones on 07/05/2025.
//

import AppKit

extension MainWindowViewModel {
    func newButton() {
        if archive != nil && archive?.dirty == true {
            closeButton() { self.newButton() }
            return
        }

        newArchive()
    }

    func openButton() {
        if archive != nil && archive?.dirty == true {
            closeButton() { self.openButton() }
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

    func closeButton(force: Bool = false, postSavePromptClosure: (() -> Void)? = nil) {
        guard let archive else { return }

        if archive.dirty == true && !force {
            showSavePrompt = true
            self.postSavePromptClosure = postSavePromptClosure
        } else {
            closeArchive()
        }
    }

    func revertButton() {
        guard let archive else { return }

        Task { @MainActor in
            await openArchive(url: archive.URL)
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

    func prepareExtractPanel() -> NSSavePanel {
        precondition(archive != nil, "prepareExtractPanel called without ensuring archive exists")

        let panel = NSOpenPanel()

        let button = NSButton.init()
        button.setButtonType(.switch)
        button.title = "Retain full archive path"
        button.state = .off

        panel.accessoryView = button
        panel.isAccessoryViewDisclosed = true

        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true

        return panel
    }

    func extractButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        guard let archive else { return }

        let panel = prepareExtractPanel()

        let actualEntries = entries ?? selectedEntries
        panel.prompt = "Extract \(actualEntries.count) item\(actualEntries.count > 1 ? "s" : "")"

        if panel.runModal() == .OK {
            if let destURL = panel.url {
                let button = panel.accessoryView as! NSButton
                let retainFullPath = button.state == .on
                let chosenEntries = archive.entries.filter { actualEntries.contains($0.id) }

                extractEntries(chosenEntries, archive: archive, destURL: destURL, retainFullPath: retainFullPath)
            }
        }
    }

    func extractAllButton() {
        guard let archive else { return }
        guard let chosenEntries = archive.root.children else { return }

        let panel = prepareExtractPanel()
        panel.prompt = "Extract All"

        if panel.runModal() == .OK {
            if let destURL = panel.url {
                let button = panel.accessoryView as! NSButton
                let retainFullPath = button.state == .on

                extractEntries(chosenEntries, archive: archive, destURL: destURL, retainFullPath: retainFullPath)
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
        panel.nameFieldStringValue = archive!.name.deletingPathExtension
        panel.allowedContentTypes = ArkyveFormats.writeableUTTypes
        panel.showsContentTypes = true
        panel.canCreateDirectories = true
        panel.canSelectHiddenExtension = true
        panel.isExtensionHidden = false

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

                Task {
                    AKTrace("Save As to \(destURL) (format: \(selectedArkyveFormat))")

                    if !destURL.startAccessingSecurityScopedResource() {
                        AKError("Unable to access security scope for \(destURL.path)")
                        return
                    }
                    defer { destURL.stopAccessingSecurityScopedResource() }

                    if !archive.dirty && archive.format == selectedFormat && archive.filters == selectedFilters {
                        // This is a performance optimisation
                        // The archive/format/filters haven't changed, so just copy the existing file
                        copyArchive(to: destURL)
                    } else {
                        await saveArchive(to: destURL, overrideFormat: selectedFormat, overrideFilters: selectedFilters)
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

    func expandAll(_ expand: Bool) {
        guard let archive else { return }
        archive.entries.forEach { $0.isExpanded = expand }
    }
}
