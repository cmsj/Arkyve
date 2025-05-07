//
//  ContextMenu.swift
//  Arkyve
//
//  Created by Chris Jones on 18/04/2025.
//

import SwiftUI

struct EntryContextMenu: View {
    @State var viewModel: MainWindowViewModel
    let items: Set<ArchiveEntry.ID>

    var body: some View {
        Button("New Folder") {
            viewModel.newFolderButton(entries: items)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .disabled(viewModel.disableNewFolder)

        Button("Add Files/Folders...") {
            viewModel.addButton()
        }
        .disabled(viewModel.disableAdd)

        Button("Rename...") {
            viewModel.renameButton(entries: items)
        }
        .keyboardShortcut("r", modifiers: [.command])
        .disabled(items.isEmpty)

        Button("Extract...") {
            viewModel.extractButton(items)
        }
        .keyboardShortcut("e", modifiers: [.command])
        .disabled(items.isEmpty)

        Divider()

        Button("Cut") {
            Task {
                await viewModel.cutButton(entries: items)
            }
        }
        .keyboardShortcut("x", modifiers: [.command])
        .disabled(items.isEmpty)

        Button("Copy") {
            Task {
                await viewModel.copyButton(entries: items)
            }
        }
        .keyboardShortcut("c", modifiers: [.command])
        .disabled(items.isEmpty)

        // FIXME: This doesn't respect where we have pasted
        PasteButton(supportedContentTypes: [.archiveEntryExtractable, .fileURL]) { items in
            viewModel.processDrop(for: items)
        }
        .keyboardShortcut("v", modifiers: [.command])

        Divider()

        Button("Delete") {
            viewModel.deleteButton(items)
        }
        .keyboardShortcut(.delete, modifiers: [])
        .disabled(items.isEmpty)

        Button("Quick Look") {
            viewModel.extractForQuicklook()
        }
        .keyboardShortcut(.space, modifiers: [])
        .disabled(viewModel.disableQuicklook)
    }
}
