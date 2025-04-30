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
        .disabled(viewModel.disableNewFolder)

        Button {
            viewModel.renameButton(entries: items)
        } label: {
            Text("Rename...")
        }
        .keyboardShortcut("r")
        .disabled(items.isEmpty)
        Button {
            viewModel.extractButton(items)
        } label: {
            Text("Extract")
        }
        .keyboardShortcut("e")
        .disabled(items.isEmpty)
        Divider()
        Button {
            viewModel.deleteButton(items)
        } label: {
            Text("Delete")
        }
        .keyboardShortcut(.delete, modifiers: [])
        .disabled(items.isEmpty)
    }
}
