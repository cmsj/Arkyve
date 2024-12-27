//
//  ToolbarContent.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI

struct ToolbarContentView: CustomizableToolbarContent {
    var viewModel: MainWindowViewModel

    var renameEntry: FocusState<UUID?>.Binding
    var openButtonTip = OpenButtonTip()

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "New") {
            Button {
                viewModel.newButton()
            } label: {
                Label("New archive", systemImage: "plus.rectangle.on.folder")
                    .padding()
            }
            .help("Start a new, empty archive")
        }
        ToolbarItem(id: "Open") {
            Button {
                viewModel.openButton()
            } label: {
                Label("Open", systemImage: "folder")
                    .padding()
            }
            .help("Open an archive")
            .popoverTip(openButtonTip, arrowEdge: .top)
        }
        ToolbarItem(id: "Close") {
            Button {
                viewModel.closeButton()
            } label: {
                Label("Close", systemImage: "xmark.circle")
                    .padding()
            }
            .disabled(viewModel.disableClose)
        }
// TODO: WRITE
//        ToolbarItem(id: "Add") {
//            Button {
//                viewModel.addButton()
//            } label: {
//                Label("Add", systemImage: "plus.circle")
//                    .padding()
//            }
//            .help("Add files to the archive")
//            .disabled(viewModel.archive == nil)
//        }
        ToolbarItem(id: "Extract") {
            Button {
                viewModel.extractButton()
            } label: {
                Label("Extract", systemImage: "folder.badge.minus")
                    .padding()
            }
            .help("Extract selected files/folders")
            .disabled(viewModel.disableExtract)
        }
        ToolbarItem(id: "Rename") {
            Button {
                viewModel.renameButton(renameEntryFocus: renameEntry)
            } label: {
                Label("Rename", systemImage: "character.cursor.ibeam")
                    .padding()
            }
            .help("Rename selected file/folder")
            .disabled(viewModel.disableRename)
        }
//        ToolbarItem(id: "Delete") {
//            Button {
//                viewModel.deleteButton()
//            } label: {
//                Label("Delete", systemImage: "trash")
//                    .padding()
//            }
//            .help("Delete selected files/folders")
//            .disabled(viewModel.disableDelete)
//        }
    }
}

//#Preview {
//    VStack {
//        Spacer()
//        HStack {
//            Spacer()
//            Text("Preview")
//                .padding(300.0)
//            Spacer()
//        }
//        Spacer()
//    }
//    .toolbar(id: "Preview") {
//        ToolbarContentView(viewModel: MainWindowViewModel())
//    }
//}
