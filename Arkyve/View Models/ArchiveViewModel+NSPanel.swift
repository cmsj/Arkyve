//
//  ArchiveViewModel+NSPanel.swift
//  Arkyve
//
//  Created by Chris Jones on 09/06/2025.
//

import AppKit

extension ArchiveViewModel {
    func prepareSaveAsPanel() -> NSSavePanel {
        let panel = NSSavePanel()

        panel.prompt = "Save"
        panel.nameFieldStringValue = name.deletingPathExtension
        panel.allowedContentTypes = ArkyveFormats.writeableUTTypes
        panel.showsContentTypes = true
        panel.canCreateDirectories = true
        panel.canSelectHiddenExtension = true
        panel.isExtensionHidden = false

        let currentFormat = ArkyveFormats.initFromlibarchiveFormatForSaving(format, withFilters: filters)
        panel.currentContentType = currentFormat.utType

        return panel
    }

    func prepareExtractPanel(overrideTopDirectory: Bool? = nil) -> NSSavePanel? {
        let panel = NSOpenPanel()

        let retainPathButton = NSButton.init()
        retainPathButton.setButtonType(.switch)
        retainPathButton.title = "Retain full archive path"
        retainPathButton.state = .off

        let addTopDirectory = NSButton.init()
        addTopDirectory.setButtonType(.switch)
        addTopDirectory.title = "Extract into a directory called '\(name.deletingPathExtension)'"
        addTopDirectory.state = .off

        if let overrideTopDirectory {
            addTopDirectory.state = overrideTopDirectory ? .on : .off
        } else {
            if offerTopDirectory {
                addTopDirectory.state = .on
            }
        }

        let accessoryButtons = [retainPathButton, addTopDirectory]

        let vStack = NSStackView(views: accessoryButtons)
        vStack.orientation = .vertical
        vStack.alignment = .leading
        vStack.edgeInsets = .init(top: 5, left: 5, bottom: 5, right: 5)

        panel.accessoryView = vStack
        panel.isAccessoryViewDisclosed = true

        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true

        return panel
    }
}
