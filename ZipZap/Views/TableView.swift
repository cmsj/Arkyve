//
//  TableView.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import QuickLook

struct TableView: View {
    @Environment(MainWindowViewModel.self) var viewModel

    @SceneStorage("ArchiveEntryTableConfig") private var columnCustomization: TableColumnCustomization<ArchiveEntry>
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.name)]

    var renameEntry: FocusState<UUID?>.Binding

    var body: some View {
        // FIXME: This @Bindable is an ugly hack: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
        @Bindable var viewModel = viewModel

        Table(of: ArchiveEntry.self, selection: $viewModel.selectedEntries, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            TableColumn("Name", value: \ArchiveEntry.name) { entry in
                @Bindable var entry = entry
                HStack {
                    Image(systemName: entry.type.rawValue)
                    TextField(entry.name, text: $entry.name)
                        .focused(renameEntry, equals: entry.id)
                        .onSubmit {
                            viewModel.doRename(of: entry)
                        }
                }
            }
            .customizationID("name")
            TableColumn("Size", value: \ArchiveEntry.sizeString)
                .customizationID("sizeString")
                .alignment(.trailing)
            TableColumn("Kind", value: \ArchiveEntry.type.userString)
                .customizationID("type")
                .defaultVisibility(.hidden)
            TableColumn("Date Modified", value: \ArchiveEntry.mtime.userFormatted)
                .customizationID("mtime")
            TableColumn("Permissions", value: \ArchiveEntry.perms)
                .customizationID("perms")
                .defaultVisibility(.hidden)
            TableColumn("UID", value: \ArchiveEntry.uid)
                .customizationID("uid")
                .defaultVisibility(.hidden)
            TableColumn("GID", value: \ArchiveEntry.uid)
                .customizationID("gid")
                .defaultVisibility(.hidden)
            TableColumn("Date Changed", value: \ArchiveEntry.ctime.userFormatted)
                .customizationID("ctime")
                .defaultVisibility(.hidden)
            TableColumn("Date Accessed", value: \ArchiveEntry.atime.userFormatted)
                .customizationID("atime")
                .defaultVisibility(.hidden)
            TableColumn("Date Created", value: \ArchiveEntry.btime.userFormatted)
                .customizationID("btime")
                .defaultVisibility(.hidden)
        } rows: {
            TableRowTreeContent(children: viewModel.archive?.root.children ?? [], viewModel: viewModel)
        }
        .contextMenu(forSelectionType: ArchiveEntry.ID.self) { items in
            Button {
                viewModel.renameButton(renameEntry: renameEntry, entries: items)
            } label: {
                Text("Rename...")
            }
            .disabled(items.count != 1)
            Button {
                viewModel.extractButton(items)
            } label: {
                Text("Extract")
            }
            Divider()
            Button {
                // FIXME: Implement
            } label: {
                Text("Delete")
            }
        }
        .onKeyPress(.space, action: {
            if viewModel.selectedEntries.count > 0 {
                viewModel.extractForQuicklook()
                return .handled
            } else {
                // It's not completely obvious that this is entirely necessary, but since we can easily distinguish if the user wanted Quick Look or not, we might as well vary our behaviour accordingly.
                return .ignored
            }
        })
        .quickLookPreview($viewModel.quickLookURL, in: viewModel.quickLookItems)
        .onChange(of: sortOrder) { _, newSortOrder in
            viewModel.sort(using: sortOrder)
        }
    }
}

//#Preview {
//    TableView()
//        .environment(MainWindowViewModel())
//}
