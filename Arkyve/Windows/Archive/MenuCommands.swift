//
//  Menus.swift
//  Arkyve
//
//  Created by Chris Jones on 27/12/2024.
//

import SwiftUI

struct MenuCommands: Commands {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openWindow) var openWindow

    @FocusedValue(\.activeViewModel) var activeViewModel
    @StateObject var settingsManager: SettingsManager

    var body: some Commands {
        CommandGroup(replacing: .singleWindowList) {
            Button(action: {
                openWindow(id: "splash")
            }) {
                Text("Welcome to Arkyve")
            }
        }
        // About
        CommandGroup(replacing: CommandGroupPlacement.appInfo) {
            Button(action: {
                openWindow(id: "about")
            }) {
                Text("About Arkyve")
            }
        }

        // Remove undo/redo
        CommandGroup(replacing: .undoRedo) {}

        // File Menu
        CommandGroup(after: .newItem) {
            Button("Open...") {
                openArchiveFromPanel(openWindow: openWindow)
            }
            .keyboardShortcut("o", modifiers: [.command])

            Menu("Open Recent") {
                ForEach(settingsManager.recents, id: \.self) { url in
                    Button(action: {
                        AKTrace("Open Recent Menu: \(url)")
                        openArchiveFromURL(url, openWindow: openWindow)
                    }) {
                        Text(url.lastPathComponent)
                    }
                }
                Divider()
                Button(action: {
                    settingsManager.clearRecents()
                }) {
                    Text("Clear Menu")
                }
                .disabled(settingsManager.recents.isEmpty)
            }
        }

        CommandGroup(before: .saveItem) {
            Button("Revert to Saved") {
                activeViewModel?.revertButton()
            }
            .disabled(activeViewModel?.disableRevert ?? true)

            Divider()

            Button("Save") {
                activeViewModel?.saveButton()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(activeViewModel?.disableSave ?? true)

            Button("Save As...") {
                activeViewModel?.saveAsButton()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(activeViewModel?.disableSaveAs ?? true)

            Button("Extract All...") {
                activeViewModel?.extractAllButton()
            }
            .keyboardShortcut("e", modifiers: [.command, .option])
            .disabled(activeViewModel?.disableExtractAll ?? true)

            Divider()
        }

        CommandGroup(after: .pasteboard) {
            Button("Find") {
                activeViewModel?.searchPresented = true
            }
            .keyboardShortcut("f", modifiers: [.command])
            .disabled(activeViewModel?.disableSearchMenu ?? true)
        }
        // View Menu
        CommandGroup(after: .toolbar) {
            Button("Expand all") {
                activeViewModel?.expandAll(true)
            }
            .disabled(activeViewModel?.disableExpandCollapse ?? true)
            Button("Collapse all") {
                activeViewModel?.expandAll(false)
            }
            .disabled(activeViewModel?.disableExpandCollapse ?? true)
        }

        // Items Menu
        CommandMenu("Items") {
            Button("New Folder") {
                activeViewModel?.newFolderButton()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(activeViewModel?.disableNewFolder ?? true)
            
            Button("Add Files/Folders...") {
                activeViewModel?.addButton()
            }
            .keyboardShortcut("i", modifiers: [.command])
            .disabled(activeViewModel?.disableAdd ?? true)
            
            Divider()
            
            Button("Delete") {
                activeViewModel?.deleteButton()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(activeViewModel?.disableDelete ?? true)
            
            Divider()
            
            Button("Rename...") {
                activeViewModel?.renameButton()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(activeViewModel?.disableRename ?? true)
            
            Button("Extract...") {
                activeViewModel?.extractButton()
            }
            .keyboardShortcut("e", modifiers: [.command])
            .disabled(activeViewModel?.disableExtract ?? true)
            
            Button("Extract All...") {
                activeViewModel?.extractAllButton()
            }
            .keyboardShortcut("e", modifiers: [.command, .option])
            .disabled(activeViewModel?.disableExtractAll ?? true)
            
            Divider()
            
            Button("Quick Look") {
                activeViewModel?.resetQuickLook()
                activeViewModel?.extractForQuicklook()
            }
            .keyboardShortcut("y", modifiers: [.command])
            .disabled(activeViewModel?.disableQuicklook ?? true)
            
            // FIXME: ShareLink ignores .disabled() in a menu, so we wrap it in a conditional instead. FB17656789
            if let activeViewModel, !activeViewModel.disableShare {
                ShareLink(items: activeViewModel.extractablesForSelected(),
                          subject: nil,
                          message: nil,
                          preview: { SharePreview($0.name, icon: $0.icon) }
                )
                .disabled(activeViewModel.disableShare)
            }
        }
    }
}
