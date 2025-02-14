//
//  Menus.swift
//  ZipZap
//
//  Created by Chris Jones on 27/12/2024.
//

import SwiftUI

struct MenuCommands: Commands {
    @FocusedValue(\.activeViewModel) var activeViewModel

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {}
        CommandGroup(after: .newItem) {
            Button("New") {
                activeViewModel?.newButton()
            }
            .keyboardShortcut("n", modifiers: [.command])
            Button("Open...") {
                activeViewModel?.openButton()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(activeViewModel == nil)
            Button("Revert") {
                activeViewModel?.revertButton()
            }
            .disabled(activeViewModel?.disableRevert ?? true)
            Divider()
            Button("Save") {
                activeViewModel?.saveButton()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(activeViewModel?.disableSave ?? true)
            .modifierKeyAlternate(.option) {
                Button("Save As...") {
                    activeViewModel?.saveAsButton()
                }
                .disabled(activeViewModel?.disableSaveAs ?? true)
            }
            Divider()
            Button("Close Archive") {
                activeViewModel?.closeButton()
            }
            .disabled(activeViewModel?.disableClose ?? true)
        }
        CommandGroup(after: .sidebar) {
            Button("Quick Look") {
                activeViewModel?.extractForQuicklook()
            }
            .keyboardShortcut("y", modifiers: [.command])
            .disabled(activeViewModel?.disableQuicklook ?? true)
            Divider()
        }
    }
}
