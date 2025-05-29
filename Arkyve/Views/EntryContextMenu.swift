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

        Button("Add Files/Folders...") {
            viewModel.addButton()
        }
        .disabled(viewModel.disableAdd)

        Divider()

        Button("Delete") {
            viewModel.deleteButton(items)
        }
        .disabled(items.isEmpty)

        Divider()

        Button("Rename...") {
            viewModel.renameButton(entries: items)
        }
        .disabled(items.isEmpty)

        Button("Extract...") {
            viewModel.extractButton(items)
        }
        .disabled(items.isEmpty)

        Divider()

        Button("Cut") {
            Task {
                await viewModel.cutButton(entries: items)
            }
        }
        .disabled(items.isEmpty)

        Button("Copy") {
            Task {
                await viewModel.copyButton(entries: items)
            }
        }
        .disabled(items.isEmpty)

        PasteButton(supportedContentTypes: [.archiveEntryExtractable, .fileURL]) { providers in
            viewModel.processDrop(on: self.items.first, for: providers)
        }

        // FIXME: ShareLink ignores .disabled() in a menu, so we wrap it in a conditional instead. FB17656789
        if items.count > 0 {
            ShareLink(items: viewModel.extractablesForSelected(), subject: nil, message: nil, preview: {
                let name = $0.name
                let icon = $0.icon
                return SharePreview(name, icon: icon)
            })
            .disabled(items.isEmpty)
        }

        Divider()

        Button("Quick Look\(viewModel.nameForQuickLook(items: items))") {
            viewModel.extractForQuicklook()
        }
        .disabled(items.isEmpty)
    }
}

#Preview {
    EntryContextMenu(viewModel: MainWindowViewModel(), items: [])
}
