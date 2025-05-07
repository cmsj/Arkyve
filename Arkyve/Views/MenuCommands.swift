//
//  Menus.swift
//  Arkyve
//
//  Created by Chris Jones on 27/12/2024.
//

import SwiftUI

struct MenuCommands: Commands {
    @State var viewModel: MainWindowViewModel

    var body: some Commands {
        // Remove undo/redo
        CommandGroup(replacing: .undoRedo) {}

        // File Menu
        CommandGroup(after: .newItem) {
            Button("New") {
                viewModel.newButton()
            }
            .keyboardShortcut("n", modifiers: [.command])
            Button("Open...") {
                viewModel.openButton()
            }
            .keyboardShortcut("o", modifiers: [.command])
            Button("Revert") {
                viewModel.revertButton()
            }
            .disabled(viewModel.disableRevert)

            Divider()

            Button("Save") {
                viewModel.saveButton()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(viewModel.disableSave)

            Button("Save As...") {
                viewModel.saveAsButton()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(viewModel.disableSaveAs)

            Divider()

            Button("Close Archive") {
                viewModel.closeButton()
            }
            .disabled(viewModel.disableClose)
        }

        // View Menu
        CommandGroup(after: .toolbar) {
            Button("Expand all") {
                viewModel.expandAll(true)
            }
            .disabled(viewModel.disableExpandCollapse)
            Button("Collapse all") {
                viewModel.expandAll(false)
            }
            .disabled(viewModel.disableExpandCollapse)
        }

        // Items Menu
        CommandMenu("Items") {
            Button("New Folder") {
                viewModel.newFolderButton()
            }
            .keyboardShortcut("n", modifiers:[.command, .shift])
            .disabled(viewModel.disableNewFolder)

            Button("Add Files/Folders...") {
                viewModel.addButton()
            }
            .disabled(viewModel.disableAdd)

            Button("Rename") {
                viewModel.renameButton()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(viewModel.disableRename)

            Button("Extract...") {
                viewModel.extractButton()
            }
            .keyboardShortcut("e", modifiers: [.command])
            .disabled(viewModel.disableExtract)

            Button("Extract All...") {
                viewModel.extractAllButton()
            }
            .disabled(viewModel.disableExtractAll)

            Divider()

            Button("Delete") {
                viewModel.deleteButton()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(viewModel.disableDelete)

            Button("Quick Look") {
                viewModel.extractForQuicklook()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(viewModel.disableQuicklook)
        }
    }
}
