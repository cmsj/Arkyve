//
//  DummyTableView.swift
//  Arkyve
//
//  Created by Chris Jones on 25/05/2025.
//

import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct DummyTableView: View {
    @Environment(MainWindowViewModel.self) var viewModel
    @Environment(\.isEnabled) var isEnabled

    @State private var dummyRows: [ArchiveEntry] = []
    @State private var searchQuery: String = ""
    @State private var isSearchPresented: Bool = false

    var body: some View {
        Table(dummyRows) {
                TableColumn("Name", value: \ArchiveEntry.name)
        }
        .opacity(isEnabled ? 1.0 : 0.5)
        .dropDestination(for: DropItem.self) { items, _  in
            print("DummyTableView: dropDestination")
            if viewModel.archive == nil {
                viewModel.newButton()
            }

            guard viewModel.archive != nil else { return false }

            viewModel.handleManyDrops(items: items)
            return true
        }
        .searchable(text: $searchQuery, isPresented: $isSearchPresented)
    }
}

#Preview {
    let viewModel = MainWindowViewModel()

    VStack {
        DummyTableView()
            .environment(viewModel)
    }
    .toolbar(id: "Preview") {
        ToolbarContentView(viewModel: viewModel)
    }
}
