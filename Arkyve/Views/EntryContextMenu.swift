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

        Divider()

        Button("Delete") {
            viewModel.deleteButton(items)
        }
        .disabled(items.isEmpty)

        Button("Quick Look\(viewModel.nameForQuickLook(items: items))") {
            viewModel.extractForQuicklook()
        }
        .disabled(items.isEmpty)

        ShareLink(items: viewModel.extractablesForSelected(),
                  subject: Text("subject"),
                  message: Text("message"),
                  preview: { extractable in
            SharePreview(extractable.name, icon: extractable.icon)
        }
        )
        .help("Share...")
        .disabled(viewModel.disableShare)
    }
}
