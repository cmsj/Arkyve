//
//  ArchiveViewModel+Buttons.swift
//  Arkyve
//
//  Created by Chris Jones on 09/06/2025.
//

import AppKit

extension ArchiveViewModel {
    // MARK: - Button actions
    func newFolderButton(items: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = items ?? selectedEntries
        var parentEntryID: UUID = root.id

        // See if we can be more specific than the root entry being the parent
        if let firstItem = actualEntries.first {
            if let tmpParentEntry = entryForID(firstItem) {
                if tmpParentEntry.type == .directory {
                    // We have a selected entry and it's a directory, we can parent directly to it
                    parentEntryID = firstItem
                } else {
                    // We have a selected entry, but it's not a directory, so let's find its parent
                    if let tmpGrandParentEntry = parentForEntry(tmpParentEntry) {
                        parentEntryID = tmpGrandParentEntry.id
                    }
                }
            }
        }

        if let newFolderID = newFolder(at: parentEntryID) {
            // The MainActor tasks here are a way to defer something to after the UI has ticked,
            // so it notices the state changing sequentially
            Task { @MainActor in
                selectedEntries = [newFolderID]
                entryForID(parentEntryID)?.isExpanded = true

                Task { @MainActor in
                    focusedEntry = newFolderID
                }
            }
        }
    }

    func addButton(on: ArchiveEntry.ID? = nil) {
        var parentEntry = entryForID(on ?? root.id)
        if parentEntry != nil && parentEntry!.children == nil {
            parentEntry = parentForEntry(parentEntry!) ?? root
        }

        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.prompt = "Select files/folders to add"

        if panel.runModal() == .OK {
            do {
                try scopedURLManager.store(panel.urls, forOperation: .addFiles)
                try addFiles(from: panel.urls, parent: parentEntry)
                sort()
                parentEntry?.isExpanded = true
            } catch {
                errors.err(error)
            }
        }
    }

    func saveButton() {
        if diskURL == nil || format.canWrite == false {
            // We're trying to save, but the archive has never been written to disk, so we need to do a Save As
            saveAsButton()
            return
        }

        guard let diskURL else { return }
        saveArchiveWithTask(to: diskURL)
    }

    func saveAsButton() {
        let panel = prepareSaveAsPanel()

        if panel.runModal() == .OK {
            if let destURL = panel.url {
                guard let selectedArkyveFormat = ArkyveFormats.initFromUTType(panel.currentContentType) else {
                    AKError("Unable to determine which archive format the user selected")
                    return
                }
                let selectedFormat = selectedArkyveFormat.libarchiveFormat
                let selectedFilters = selectedArkyveFormat.libarchiveFilters

                do {
                    try scopedURLManager.store(destURL, forOperation: .writeArchive)
                } catch {
                    AKWarning("Unable to activate scoped URL bookmark: \(destURL) for .writeArchive. Attempting to continue")
                }

                AKTrace("Save As to \(destURL) (format: \(selectedArkyveFormat))")

                if !dirty && format == selectedFormat && filters == selectedFilters {
                    // This is a performance optimisation
                    // The archive/format/filters haven't changed, so just copy the existing file
                    copyArchive(to: destURL)
                } else {
                    saveArchiveWithTask(to: destURL, overrideFormat: selectedFormat, overrideFilters: selectedFilters)
                }
            }
        }
    }

    func revertButton() {
        guard let diskURL, dirty == true else { return }

        let alert = NSAlert()
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Revert Archive")
        alert.buttons.last?.hasDestructiveAction = true
        alert.alertStyle = .critical
        alert.messageText = "Revert without saving?"
        alert.informativeText = "\(name) has unsaved changes, do you want to revert it without saving?"

        let response = alert.runModal()

        // runModal() has various return values, we are going to ignore any that aren't specific button presses
        switch response {
        case .alertSecondButtonReturn:
            // Revert to on-disk archive
            reinit(for: diskURL)
        default:
            // Any other path means we're not reverting
            break
        }
    }

    func deleteButton(_ entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        removeEntries(actualEntries)

        // Curiously, the selection binding doesn't clear automatically when we remove items from the table
        selectedEntries.removeAll()
    }

    func renameButton(entries: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = entries ?? selectedEntries
        focusedEntry = actualEntries.first
    }

    func expandAll(_ expand: Bool) {
        entries.forEach { $0.isExpanded = expand }
    }

    func extractButton(_ items: Set<ArchiveEntry.ID>? = nil) {
        let actualEntries = items ?? selectedEntries
        let overrideTopDirectory = actualEntries.count == 1 ? false : true
        guard let panel = prepareExtractPanel(overrideTopDirectory: overrideTopDirectory) else { return }

        panel.prompt = "Extract \(actualEntries.count) item\(actualEntries.count > 1 ? "s" : "")"

        if panel.runModal() == .OK {
            if var destURL = panel.url {
                let vStack = panel.accessoryView as! NSStackView
                let retainPathButton = vStack.views[0] as! NSButton
                let addTopDirectoryButton = vStack.views[1] as! NSButton

                let retainFullPath = retainPathButton.state == .on
                if addTopDirectoryButton.state == .on {
                    destURL = destURL.appendingPathComponent(name.deletingPathExtension)
                }

                let chosenEntries = entries.filter { actualEntries.contains($0.id) }

                extractEntriesWithConfirmation(chosenEntries, destURL: destURL, retainFullPath: retainFullPath)
            }
        }
    }

    func extractAllButton() {
        guard let chosenEntries = root.children else { return }

        guard let panel = prepareExtractPanel(overrideTopDirectory: offerTopDirectory) else { return }
        panel.prompt = "Extract All"

        if panel.runModal() == .OK {
            if var destURL = panel.url {
                let vStack = panel.accessoryView as! NSStackView
                let retainPathButton = vStack.views[0] as! NSButton
                let addTopDirectoryButton = vStack.views[1] as! NSButton

                let retainFullPath = retainPathButton.state == .on
                if addTopDirectoryButton.state == .on {
                    destURL = destURL.appendingPathComponent(name.deletingPathExtension)
                }

                extractEntriesWithConfirmation(chosenEntries, destURL: destURL, retainFullPath: retainFullPath)
            }
        }
    }
}
