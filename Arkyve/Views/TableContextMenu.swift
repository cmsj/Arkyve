//
//  TableContextMenu.swift
//  Arkyve
//
//  Created by Chris Jones on 21/04/2025.
//

import SwiftUI

struct TableContextMenu: View {
    @State var viewModel: MainWindowViewModel
    var renameEntryFocus: FocusState<UUID?>.Binding

    var body: some View {
        Button {
            viewModel.addButton()
        } label: {
            Text("Add files/folders...")
        }
//        .keyboardShortcut("r")
    }
}
