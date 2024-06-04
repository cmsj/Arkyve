//
//  TableView.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI

struct TableView: View {
    @Environment(MainWindowViewModel.self) var viewModel
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.path)]
    @SceneStorage("ArchiveEntryTableConfig")
    private var columnCustomization: TableColumnCustomization<ArchiveEntry>

    var body: some View {
        // FIXME: This is an ugly hack: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
        @Bindable var viewModel = viewModel

        Table(of: ArchiveEntry.self, selection: $viewModel.selectedEntries, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            TableColumn("Name") { entry in
                HStack {
                    Image(systemName: entry.type.rawValue)
                    Text(entry.name)
                }
            }
            .customizationID("name")
            TableColumn("Size", value: \.sizeString) //{ size in
//                    Text(size)
//                        .overlay( GeometryReader { geo in Color.clear.onAppear { sizeWidth = geo.size.width }})
//                }
                .customizationID("sizeString")
//                    .alignment(.trailing)
//                    .width(min: sizeWidth, max: sizeWidth)
            TableColumn("Date Modified", value: \.mtime.userFormatted)
                .customizationID("mtime")
            TableColumn("Permissions", value: \.perms)
                .customizationID("perms")
            TableColumn("UID", value: \.uid)
                .customizationID("uid")
                .defaultVisibility(.hidden)
            TableColumn("GID", value: \.uid)
                .customizationID("gid")
                .defaultVisibility(.hidden)
            TableColumn("Date Changed", value: \.ctime.userFormatted)
                .customizationID("ctime")
                .defaultVisibility(.hidden)
            TableColumn("Date Accessed", value: \.atime.userFormatted)
                .customizationID("atime")
                .defaultVisibility(.hidden)
            TableColumn("Date Created", value: \.btime.userFormatted)
                .customizationID("btime")
                .defaultVisibility(.hidden)
        } rows: {
            TableRowTreeContent(children: viewModel.archive?.root.children ?? [])
        }
        .onChange(of: sortOrder) { _, sortOrder in
            // FIXME: Make this a viewmodel func call
            viewModel.archive?.sort(using: sortOrder)
        }
    }
}

#Preview {
    TableView()
}
