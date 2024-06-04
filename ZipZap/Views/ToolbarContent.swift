//
//  ToolbarContent.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI

struct ToolbarContentView: CustomizableToolbarContent {
    var viewModel: MainWindowViewModel

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "New") {
            Button {
                viewModel.newButton()
            } label: {
                Label("New", systemImage: "folder.badge.plus")
                    .padding()
            }
        }
        ToolbarItem(id: "Open") {
            Button {
                viewModel.openButton()
            } label: {
                Label("Open...", systemImage: "folder")
                    .padding()
            }
        }
        ToolbarItem(id: "Close") {
            Button {
                viewModel.closeButton()
            } label: {
                Label("Close", systemImage: "xmark.circle")
                    .padding()
            }
            .disabled(viewModel.archive == nil)
        }
        ToolbarItem(id: "Add"){
            Button {

            } label: {
                Label("Add", systemImage: "plus.circle")
                    .padding()
            }
            .disabled(viewModel.archive == nil)
        }
        ToolbarItem(id: "Extract"){
            Button {
                viewModel.extractButton()
            } label: {
                Label("Extract", systemImage: "folder.badge.minus")
                    .padding()
            }
            .disabled(viewModel.selectedEntries.isEmpty)
        }
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
