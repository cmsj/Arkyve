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

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "progress") {
            ZStack {
                ProgressView(value: viewModel.progress.value)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .opacity({
                        switch viewModel.progress {
                        case .determinate(_): return 1.0
                        default: return 0.0
                        }
                    }())
                ProgressView()
                    .controlSize(.small)
                    .opacity(viewModel.progress == .indeterminate ? 1.0 : 0.0)
            }
            .help("Progress: \(viewModel.progress)")

        }
        .customizationBehavior(.reorderable)
        .hidden(viewModel.progress == .idle)
        ToolbarItem(id: "cancel") {
            Button {
                viewModel.progressTask?.cancel()
            } label: {
                Label("Stop", systemImage: "stop.circle")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Stop the current archive task")
        }
        .customizationBehavior(.reorderable)
        .hidden(viewModel.progressTask == nil)
        ToolbarItem(id: "divider") {
            HStack {
                Divider()
            }
        }
        .hidden(viewModel.progress == .idle)

        ToolbarItem(id: "New") {
            Button {
                viewModel.newButton()
            } label: {
                Label("New", systemImage: "plus.rectangle.on.folder")
                    .symbolRenderingMode(.hierarchical)
                    .padding()
            }
            .help("Create a new archive")
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
                viewModel.renameButton()
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
