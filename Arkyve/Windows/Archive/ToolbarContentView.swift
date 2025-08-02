//
//  ToolbarContent.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import TipKit

struct ToolbarContentView: CustomizableToolbarContent {
    @State var viewModel: ArchiveViewModel
    @StateObject var settingsManager: SettingsManager
    @State private var renderingMode: SymbolRenderingMode = .hierarchical

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "progress") {
            ProgressView()
                .controlSize(.small)
                .help("Working...")
        }
        .customizationBehavior(.reorderable)
        .hidden(viewModel.progressTask == nil)

        ToolbarItem(id: "cancel") {
            Button {
                viewModel.isCancelling = true
                viewModel.progressTask?.cancel()
            } label: {
                Label("Stop", systemImage: "stop.circle")
                    .symbolRenderingMode(renderingMode)
            }
            .disabled(viewModel.progressTask == nil)
            .help("Stop the current task")
        }
        .customizationBehavior(.reorderable)
        .hidden(viewModel.progressTask == nil)

        ToolbarItem(id: "Add") {
            Button {
                viewModel.addButton()
            } label: {
                Label("Add", systemImage: "plus")
                    .symbolRenderingMode(renderingMode)
            }
            .help("Add files/folders to this archive")
            .disabled(viewModel.disableAdd)
        }
        ToolbarItem(id: "Extract") {
            Button {
                viewModel.extractButton()
            } label: {
                Label("Extract", image: "custom.arrow.down.rectangle.stack")
                    .symbolRenderingMode(renderingMode)
            }
            .help("Extract selected files/folders")
            .disabled(viewModel.disableExtract)
        }
        ToolbarItem(id: "Rename") {
            Button {
                viewModel.renameButton()
            } label: {
                Label("Rename", systemImage: "character.cursor.ibeam")
                    .symbolRenderingMode(.hierarchical)
            }
            .help("Rename selected file/folder")
            .disabled(viewModel.disableRename)
        }
        ToolbarItem(id: "Delete") {
            Button {
                viewModel.deleteButton()
            } label: {
                Label("Delete", systemImage: "trash")
                    .symbolRenderingMode(renderingMode)
            }
            .help("Delete selected files/folders")
            .disabled(viewModel.disableDelete)
        }
        ToolbarItem(id: "Share") {
            ShareLink(items: viewModel.extractablesForSelected(),
                      subject: nil,
                      message: nil,
                      preview: { $0.sharePreview }
            )
            .symbolRenderingMode(.hierarchical)
            .help("Share...")
            .disabled(viewModel.disableShare)
        }

//#if DEBUG
//        ToolbarItem(id: "ShowError") {
//            Button {
//                viewModel.errors.err(.init(.openArchive, msg: "test2"))
//            } label: {
//                Label("DEBUG ERROR", systemImage: "ant.circle")
//                    .symbolRenderingMode(.hierarchical)
//                    .padding()
//            }
//            .help("Force an error to appear")
//        }
//        .hidden(settingsManager.showDebugUI == false)
//#endif
    }
}

#Preview {
    let settingsManager = SettingsManager.shared
    let sbm = ScopedURLManager.dropSBM
    let cacheManager = CacheManager.dropCache
    let viewModel = ArchiveViewModel(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, settingsManager: settingsManager, scopedURLManager: sbm, cacheManager: cacheManager)

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
        ToolbarContentView(viewModel: viewModel, settingsManager: settingsManager)
    }
}
