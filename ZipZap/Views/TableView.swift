//
//  TableView.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct TableView: View {
    @Environment(MainWindowViewModel.self) var viewModel

    @SceneStorage("ArchiveEntryTableConfig") private var columnCustomization: TableColumnCustomization<ArchiveEntry>
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.name)]

    var renameEntryFocus: FocusState<UUID?>.Binding

    var body: some View {
        // NOTE: This @Bindable is an ugly hack: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
        @Bindable var viewModel = viewModel

        Table(of: ArchiveEntry.self, selection: $viewModel.selectedEntries, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            Group {
                TableColumn("Name", value: \ArchiveEntry.name) { entry in
                    @Bindable var entry = entry
                    HStack {
                        Image(systemName: entry.type.rawValue)
                        TextField(entry.name, text: $entry.name)
                            .focused(renameEntryFocus, equals: entry.id)
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
            }
            Group {
                TableColumn("Date Modified", value: \ArchiveEntry.mtime.userFormatted)
                    .customizationID("mtime")
                TableColumn("Date Changed", value: \ArchiveEntry.ctime.userFormatted)
                    .customizationID("ctime")
                    .defaultVisibility(.hidden)
                TableColumn("Date Accessed", value: \ArchiveEntry.atime.userFormatted)
                    .customizationID("atime")
                    .defaultVisibility(.hidden)
                TableColumn("Date Created", value: \ArchiveEntry.btime.userFormatted)
                    .customizationID("btime")
                    .defaultVisibility(.hidden)
            }
            Group {
                TableColumn("Permissions", value: \ArchiveEntry.permsString)
                    .customizationID("perms")
                    .defaultVisibility(.hidden)
                TableColumn("UID", value: \ArchiveEntry.uidString)
                    .customizationID("uid")
                    .defaultVisibility(.hidden)
                TableColumn("GID", value: \ArchiveEntry.gidString)
                    .customizationID("gid")
                    .defaultVisibility(.hidden)
                TableColumn("Synthetic", value: \ArchiveEntry.isSynthesizedString)
                    .customizationID("synth")
                    .defaultVisibility(.hidden)
            }
            Group {
                TableColumn("UUID (Debug)", value: \ArchiveEntry.id.uuidString)
                    .customizationID("uuid")
                    .defaultVisibility(.hidden)
                TableColumn("Source (Debug)", value: \ArchiveEntry.source.description)
                    .customizationID("source")
                    .defaultVisibility(.hidden)
            }

        } rows: {
            TableRowTreeContent(node: viewModel.archive?.root, viewModel: viewModel)
        }
        .contextMenu(forSelectionType: ArchiveEntry.ID.self) { items in
            EntryContextMenu(viewModel: viewModel, items: items, renameEntryFocus: renameEntryFocus)
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
        .onDrop(of: [.archiveEntryExtractable, .fileURL], isTargeted: nil, perform: { items, _ in
            guard viewModel.archive != nil else { return false }
            viewModel.processDrop(for: items)

            return true
        })
    }
}

#Preview {
    @FocusState var renameEntry: UUID?
    TableView(renameEntryFocus: $renameEntry)
        .environment(MainWindowViewModel())
}
