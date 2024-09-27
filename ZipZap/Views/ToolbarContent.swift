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

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "New") {
            Button {
                viewModel.newButton()
            } label: {
                Label("New archive", systemImage: "plus.rectangle.on.folder")
                    .padding()
            }
        }
        ToolbarItem(id: "Add") {
            Button {
                viewModel.addButton()
            } label: {
                Label("Add", systemImage: "plus.circle")
                    .padding()
            }
            .disabled(viewModel.archive == nil)
        }
        ToolbarItem(id: "Extract") {
            Button {
                viewModel.extractButton()
            } label: {
                Label("Extract", systemImage: "folder.badge.minus")
                    .padding()
            }
            .disabled(viewModel.selectedEntries.isEmpty)
        }
        ToolbarItem(id: "Rename") {
            Button {
                viewModel.renameButton(renameEntryFocus: renameEntry)
            } label: {
                Label("Rename", systemImage: "character.cursor.ibeam")
                    .padding()
            }
            .disabled(viewModel.selectedEntries.count != 1)
        }
        ToolbarItem(id: "Delete") {
            Button {
                viewModel.deleteButton()
            } label: {
                Label("Delete", systemImage: "trash")
                    .padding()
            }
            .disabled(viewModel.selectedEntries.isEmpty)
        }
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
