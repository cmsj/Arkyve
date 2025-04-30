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
        CommandGroup(replacing: .undoRedo) {}
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
            .modifierKeyAlternate(.option) {
                Button("Save As...") {
                    viewModel.saveAsButton()
                }
                .disabled(viewModel.disableSaveAs)
            }

            Divider()

            Button("Close Archive") {
                viewModel.closeButton()
            }
            .disabled(viewModel.disableClose)
        }
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
