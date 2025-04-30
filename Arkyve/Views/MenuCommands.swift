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
//        }
//        CommandGroup(replacing: .saveItem) {
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

//            Button("Close Window") {
//                viewModel.shouldCloseWindow = true
//            }
//            .keyboardShortcut("w", modifiers: [.command])
        }
        CommandGroup(after: .sidebar) {
            Button("Quick Look") {
                viewModel.extractForQuicklook()
            }
            .keyboardShortcut("y", modifiers: [.command])
            .disabled(viewModel.disableQuicklook)
            Divider()
        }
        CommandMenu("Items") {
            Button("Add Files/Folders...") {
                viewModel.addButton()
            }
            .disabled(viewModel.disableAdd)
            Button("Extract...") {
                viewModel.extractButton()
            }
            .disabled(viewModel.disableExtract)

            Divider()
        }
    }
}
