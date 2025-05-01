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

    // FIXME: Add cut/copy/paste items per https://gist.github.com/gboyegadada/43fc5950187a3417cc9c81a6ef9f5ec5#file-transferableitemexampleview-swift-L67

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
        .keyboardShortcut("r", modifiers:[.command])
        .disabled(items.isEmpty)

        Button ("Extract..."){
            viewModel.extractButton(items)
        }
        .keyboardShortcut("e", modifiers:[.command])
        .disabled(items.isEmpty)

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
