//
//  TableView.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct TableView: View {
    @Environment(MainWindowViewModel.self) var viewModel
    @Environment(\.isEnabled) var isEnabled

    @SceneStorage("ArchiveEntryTableConfig") private var columnCustomization: TableColumnCustomization<ArchiveEntry>

    @FocusState var renameEntryFocus: UUID?

    @ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 16

    var body: some View {
        // NOTE: This @Bindable is an ugly hack: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
        @Bindable var viewModel = viewModel

        Table(of: ArchiveEntry.self, selection: $viewModel.selectedEntries, sortOrder: $viewModel.sortOrder, columnCustomization: $columnCustomization) {
            Group {
                TableColumn("Name", value: \ArchiveEntry.name) { entry in
                    @Bindable var entry = entry
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(for: entry.utType))
                            .resizable()
                            .scaledToFit()
                            .frame(height: iconSize)
                        TextField(entry.name, text: $entry.name)
                            .focused($renameEntryFocus, equals: entry.id)
                            .onSubmit {
                                viewModel.doRename(of: entry)
                            }
                    }
                }
                .customizationID("name")
                TableColumn("Size (bytes)", value: \ArchiveEntry.sizeString)
                    .customizationID("sizeString")
                    .alignment(.trailing)
                    .defaultVisibility(.hidden)
                TableColumn("Size", value: \ArchiveEntry.sizeStringHuman)
                    .customizationID("sizeStringHuman")
                    .alignment(.trailing)
                TableColumn("Kind", value: \ArchiveEntry.type.userString)
                    .customizationID("type")
                    .defaultVisibility(.hidden)
            }
            Group {
                TableColumn("Date Modified", value: \ArchiveEntry.mtime.userFormatted) { entry in
                    @Bindable var entry = entry
                    Text(entry.mtime.description)
                        .popover(isPresented: $entry.mtimePopoverShowing, arrowEdge: .bottom) {
                            DateEditorView(selection: $entry.mtime, label: "Date Modified")
                        }
                        .onTapGesture(count: 2) {
                            entry.mtimePopoverShowing = true
                        }
                        .onChange(of: entry.mtime) {
                            viewModel.archive?.setDirty()
                        }
                }
                    .customizationID("mtime")

                TableColumn("Date Changed", value: \ArchiveEntry.ctime.userFormatted) { entry in
                    @Bindable var entry = entry
                    Text(entry.ctime.description)
                        .popover(isPresented: $entry.ctimePopoverShowing, arrowEdge: .bottom) {
                            DateEditorView(selection: $entry.ctime, label: "Date Changed")
                        }
                        .onTapGesture(count: 2) {
                            entry.ctimePopoverShowing = true
                        }
                        .onChange(of: entry.ctime) {
                            viewModel.archive?.setDirty()
                        }
                }
                    .customizationID("ctime")
                    .defaultVisibility(.hidden)

                TableColumn("Date Accessed", value: \ArchiveEntry.atime.userFormatted) { entry in
                    @Bindable var entry = entry
                    Text(entry.atime.description)
                        .popover(isPresented: $entry.atimePopoverShowing, arrowEdge: .bottom) {
                            DateEditorView(selection: $entry.atime, label: "Date Access")
                        }
                        .onTapGesture(count: 2) {
                            entry.atimePopoverShowing = true
                        }
                        .onChange(of: entry.atime) {
                            viewModel.archive?.setDirty()
                        }
                }
                    .customizationID("atime")
                    .defaultVisibility(.hidden)

                TableColumn("Date Created", value: \ArchiveEntry.btime.userFormatted) { entry in
                    @Bindable var entry = entry
                    Text(entry.btime.description)
                        .popover(isPresented: $entry.btimePopoverShowing, arrowEdge: .bottom) {
                            DateEditorView(selection: $entry.btime, label: "Date Changed")
                        }
                        .onTapGesture(count: 2) {
                            entry.btimePopoverShowing = true
                        }
                        .onChange(of: entry.btime) {
                            viewModel.archive?.setDirty()
                        }
                }
                    .customizationID("btime")
                    .defaultVisibility(.hidden)
            }
            Group {
                TableColumn("Permissions", value: \ArchiveEntry.permsString) { entry in
                    @Bindable var entry = entry
                    Text(entry.perms.string)
                        .popover(isPresented: $entry.permsPopoverShowing, arrowEdge: .bottom) {
                            PermsEditorView(entry: entry)
                        }
                        .onTapGesture(count: 2) {
                            entry.permsPopoverShowing = true
                        }
                }
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
                TableColumn("Symlink Target", value: \ArchiveEntry.symlinkTargetString)
                    .customizationID("symlinkTarget")
                    .defaultVisibility(.hidden)
                // FIXME: Add column for rdev
            }
#if DEBUG
            Group {
                TableColumn("UUID (Debug)", value: \ArchiveEntry.id.uuidString)
                    .customizationID("uuid")
                    .defaultVisibility(.visible)
                TableColumn("Source (Debug)", value: \ArchiveEntry.source.description)
                    .customizationID("source")
                    .defaultVisibility(.visible)
                TableColumn("Path (Debug)", value: \ArchiveEntry.path)
                    .customizationID("path")
                    .defaultVisibility(.visible)
            }
#endif

        } rows: {
            TableRowTreeContent(node: viewModel.archive?.root, viewModel: viewModel)
        }
        .copyable(viewModel.buildCopyable(entries: viewModel.selectedEntries))
        .cuttable(action: {
            viewModel.buildCuttable(entries: viewModel.selectedEntries)
        })
        .onPasteCommand(of: [.fileURL], perform: { providers in
            viewModel.processDrop(for: providers)
        })
        .opacity(isEnabled ? 1.0 : 0.5)
        .contextMenu(forSelectionType: ArchiveEntry.ID.self) { items in
            EntryContextMenu(viewModel: viewModel, items: items)
        }
        .contextMenu() {
            EntryContextMenu(viewModel: viewModel, items: Set())
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
        .onChange(of: viewModel.sortOrder) { _, _ in
            viewModel.sort()
        }
        .onChange(of: viewModel.focusedEntry) { _, newValue in
            renameEntryFocus = newValue
        }
        .onChange(of: renameEntryFocus) { _, newValue in
            viewModel.focusedEntry = newValue
        }
        .onDrop(of: [.archiveEntryExtractable, .fileURL], isTargeted: nil, perform: { items, _ in
            print("Table: onDrop")
            guard viewModel.archive != nil else { return false }
            viewModel.processDrop(for: items)

            return true
        })
    }
}

#Preview {
    let viewModel = MainWindowViewModel()

    VStack {
        TableView()
            .environment(viewModel)
    }
    .toolbar(id: "Preview") {
        ToolbarContentView(viewModel: viewModel)
    }
    .task { viewModel.newButton() }
}
