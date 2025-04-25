//
//  ToolbarContent.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import TipKit

struct ToolbarContentView: CustomizableToolbarContent {
    var viewModel: MainWindowViewModel

    var renameEntry: FocusState<UUID?>.Binding

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "New") {
            Button {
                viewModel.newButton()
            } label: {
                Label("New archive", systemImage: "plus.rectangle.on.folder")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Start a new, empty archive")
            .disabled(viewModel.disableNew)
        }
        ToolbarItem(id: "Open") {
            Button {
                viewModel.openButton()
            } label: {
                Label("Open", systemImage: "folder")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Open an archive")
            .disabled(viewModel.disableOpen)
        }
        ToolbarItem(id: "Close") {
            Button {
                viewModel.closeButton()
            } label: {
                Label("Close", image: "zzClose")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Close this archive")
            .disabled(viewModel.disableClose)
        }

        ToolbarItem(id: "Add") {
            Button {
                viewModel.addButton()
            } label: {
                Label("Add", image: "zzAdd")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Add files to this archive")
            .disabled(viewModel.disableAdd)
        }
        ToolbarItem(id: "Extract") {
            Button {
                viewModel.extractButton()
            } label: {
                Label("Extract", image: "zzExtract")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Extract selected files/folders")
            .disabled(viewModel.disableExtract)
        }
        ToolbarItem(id: "Rename") {
            Button {
                viewModel.renameButton(renameEntryFocus: renameEntry)
            } label: {
                Label("Rename", systemImage: "character.cursor.ibeam")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Rename selected file/folder")
            .disabled(viewModel.disableRename)
        }
        ToolbarItem(id: "Delete") {
            Button {
                viewModel.deleteButton()
            } label: {
                Label("Delete", systemImage: "trash")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Delete selected files/folders")
            .disabled(viewModel.disableDelete)
        }
#if DEBUG
        ToolbarItem(id: "ShowError") {
            Button {
                viewModel.showErrors.err(ArchiveError.ArchiveOpenError(archive: "test1", error: "test2"))
            } label: {
                Label("DEBUG ERROR", systemImage: "ant.circle")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Force an error to appear")
        }
#endif
    }
}

#Preview {
    @FocusState var renameEntry: UUID?

    VStack {
        Spacer()
        HStack {
            Spacer()
            Text("Preview")
                .padding(300.0)
            Spacer()
        }
        Spacer()
    }
    .toolbar(id: "Preview") {
        ToolbarContentView(viewModel: MainWindowViewModel(), renameEntry: $renameEntry)
    }
}
