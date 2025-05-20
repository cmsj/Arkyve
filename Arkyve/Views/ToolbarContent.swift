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
                viewModel.progressTask?.cancel()
            } label: {
                Label("Stop", systemImage: "stop.circle")
                    .symbolRenderingMode(renderingMode)
                    .padding()
            }
            .disabled(viewModel.progressTask == nil)
            .help("Stop the current task")
        }
        .customizationBehavior(.reorderable)
        .hidden(viewModel.progressTask == nil)

        ToolbarItem(id: "New") {
            Button {
                viewModel.newButton()
            } label: {
                Label("New", image: "custom.folder.badge.sparkles.alt")
                    .symbolRenderingMode(renderingMode)
                    .padding()
            }
            .popoverTip(viewModel.tips.createNewArchive)
            .help("Create a new archive")
            .disabled(viewModel.disableNew)
        }
        ToolbarItem(id: "Open") {
            Button {
                viewModel.openButton()
            } label: {
                Label("Open...", systemImage: "folder")
                    .symbolRenderingMode(renderingMode)
                    .padding()
            }
            .help("Open an archive")
            .disabled(viewModel.disableOpen)
        }
        ToolbarItem(id: "Close") {
            Button {
                viewModel.closeButton()
            } label: {
                Label("Close", image: "custom.folder.slash")
                    .symbolRenderingMode(renderingMode)
                    .padding()
            }
            .help("Close this archive")
            .disabled(viewModel.disableClose)
        }

        ToolbarItem(id: "divider") {
            HStack {
                Divider()
            }
        }

        ToolbarItem(id: "Add") {
            Button {
                viewModel.addButton()
            } label: {
                Label("Add", image: "custom.document.badge.plus")
                    .symbolRenderingMode(renderingMode)
                    .padding()
            }
            .help("Add files to this archive")
            .disabled(viewModel.disableAdd)
        }
        ToolbarItem(id: "Extract") {
            Button {
                viewModel.extractButton()
            } label: {
                Label("Extract...", image: "custom.folder.badge.arrow.up")
                    .symbolRenderingMode(renderingMode)
                    .padding()
            }
            .help("Extract selected files/folders")
            .disabled(viewModel.disableExtract)
        }
        ToolbarItem(id: "Share") {
            ShareLink(items: viewModel.extractablesForSelected(),
                      subject: nil,
                      message: nil,
                      preview: { SharePreview($0.name, icon: $0.icon) }
            )
            .help("Share...")
            .disabled(viewModel.disableShare)
        }
//        ToolbarItem(id: "Rename") {
//            Button {
//                viewModel.renameButton()
//            } label: {
//                Label("Rename...", systemImage: "character.cursor.ibeam")
//                    .symbolRenderingMode(.hierarchical)
//                    .padding()
//            }
//            .help("Rename selected file/folder")
//            .disabled(viewModel.disableRename)
//        }
        ToolbarItem(id: "Delete") {
            Button {
                viewModel.deleteButton()
            } label: {
                Label("Delete", systemImage: "trash")
                    .symbolRenderingMode(renderingMode)
                    .padding()
            }
            .help("Delete selected files/folders")
            .disabled(viewModel.disableDelete)
        }

//#if DEBUG
//        ToolbarItem(id: "ShowError") {
//            Button {
//                viewModel.showErrors.err(.init(.openArchive, msg: "test2"))
//            } label: {
//                Label("DEBUG ERROR", systemImage: "ant.circle")
//                    .symbolRenderingMode(.hierarchical)
//                    .padding()
//            }
//            .help("Force an error to appear")
//        }
//#endif
    }
}

#Preview {

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
        ToolbarContentView(viewModel: MainWindowViewModel())
    }
}
