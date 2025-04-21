//
//  ContextMenu.swift
//  ZipZap
//
//  Created by Chris Jones on 18/04/2025.
//

import SwiftUI

struct EntryContextMenu: View {
    @State var viewModel: MainWindowViewModel
    let items: Set<ArchiveEntry.ID>
    var renameEntryFocus: FocusState<UUID?>.Binding

    var body: some View {
        Button {
            viewModel.renameButton(renameEntryFocus: renameEntryFocus, entries: items)
        } label: {
            Text("Rename...")
        }
        .keyboardShortcut("r")
        Button {
            viewModel.extractButton(items)
        } label: {
            Text("Extract")
        }
        .keyboardShortcut("e")
        Divider()
        Button {
            viewModel.deleteButton(items)
        } label: {
            Text("Delete")
        }
        .keyboardShortcut("d")
    }
}
