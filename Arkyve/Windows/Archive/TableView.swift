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
    @Environment(ArchiveViewModel.self) var viewModel
    @Environment(\.isEnabled) var isEnabled
    @StateObject var settingsManager = SettingsManager.shared

    @AppStorage("ArchiveEntryTableConfig") private var columnCustomization: TableColumnCustomization<ArchiveEntry>

    @FocusState var renameEntryFocus: UUID?

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
                            .frame(height: CGFloat(settingsManager.iconSize))
                        TextField(entry.name, text: $entry.proposedName)
                            .focused($renameEntryFocus, equals: entry.id)
                            .onSubmit {
                                do {
                                    try viewModel.renameEntry(of: entry)
                                } catch {
                                    renameEntryFocus = entry.id
                                }
                            }
                            .onExitCommand{
                                entry.proposedName = entry.name
                                renameEntryFocus = nil
                            }
                            .onChange(of: renameEntryFocus) { _, newValue in
                                // This is here to catch scenarios where the user has entered an invalid name, but then clicked off the row without submitting
                                entry.proposedName = entry.name
                            }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Name")
                    .accessibilityValue(entry.name)
                }
                .disabledCustomizationBehavior(.visibility)
                .customizationID("name")
                TableColumn("Size", value: \ArchiveEntry.sizeStringHuman) { entry in
                    Text(entry.sizeStringHuman)
                        .foregroundStyle(.secondary)
                }
                .customizationID("sizeStringHuman")
                .alignment(.trailing)
                TableColumn("Size (bytes)", value: \ArchiveEntry.sizeString) { entry in
                    Text(entry.sizeString)
                        .foregroundStyle(.secondary)
                }
                .customizationID("sizeString")
                .alignment(.trailing)
                .defaultVisibility(.hidden)
                TableColumn("Kind", value: \ArchiveEntry.type.userString) { entry in
                    Text(entry.type.userString)
                        .foregroundStyle(.secondary)
                }
                .customizationID("type")
                .defaultVisibility(.hidden)
            }
            Group {
                TableColumn("Date Modified", value: \ArchiveEntry.mtime.finderFormatted) { entry in
                    @Bindable var entry = entry
                    Text(entry.mtime.finderFormatted)
                        .foregroundStyle(.secondary)
                        .popover(isPresented: $entry.mtimePopoverShowing, arrowEdge: .bottom) {
                            DateEditorView(selection: $entry.mtime, label: "Date Modified")
                        }
                        .onTapGesture(count: 2) {
                            entry.mtimePopoverShowing = true
                        }
                        .onChange(of: entry.mtime) {
                            viewModel.setDirty()
                        }
                        .accessibilityLabel("Date Modified")
                        .accessibilityValue(entry.mtime.finderFormatted)
                }
                .customizationID("mtime")

                TableColumn("Date Changed", value: \ArchiveEntry.ctime.finderFormatted) { entry in
                    @Bindable var entry = entry
                    Text(entry.ctime.finderFormatted)
                        .foregroundStyle(.secondary)
                        .popover(isPresented: $entry.ctimePopoverShowing, arrowEdge: .bottom) {
                            DateEditorView(selection: $entry.ctime, label: "Date Changed")
                        }
                        .onTapGesture(count: 2) {
                            entry.ctimePopoverShowing = true
                        }
                        .onChange(of: entry.ctime) {
                            viewModel.setDirty()
                        }
                        .accessibilityLabel("Date Changed")
                        .accessibilityValue(entry.ctime.finderFormatted)
                }
                .customizationID("ctime")
                .defaultVisibility(.hidden)

                TableColumn("Date Accessed", value: \ArchiveEntry.atime.finderFormatted) { entry in
                    @Bindable var entry = entry
                    Text(entry.atime.finderFormatted)
                        .foregroundStyle(.secondary)
                        .popover(isPresented: $entry.atimePopoverShowing, arrowEdge: .bottom) {
                            DateEditorView(selection: $entry.atime, label: "Date Access")
                        }
                        .onTapGesture(count: 2) {
                            entry.atimePopoverShowing = true
                        }
                        .onChange(of: entry.atime) {
                            viewModel.setDirty()
                        }
                        .accessibilityLabel("Date Accessed")
                        .accessibilityValue(entry.atime.finderFormatted)
                }
                .customizationID("atime")
                .defaultVisibility(.hidden)

                TableColumn("Date Created", value: \ArchiveEntry.btime.finderFormatted) { entry in
                    @Bindable var entry = entry
                    Text(entry.btime.finderFormatted)
                        .foregroundStyle(.secondary)
                        .popover(isPresented: $entry.btimePopoverShowing, arrowEdge: .bottom) {
                            DateEditorView(selection: $entry.btime, label: "Date Changed")
                        }
                        .onTapGesture(count: 2) {
                            entry.btimePopoverShowing = true
                        }
                        .onChange(of: entry.btime) {
                            viewModel.setDirty()
                        }
                        .accessibilityLabel("Date Created")
                        .accessibilityValue(entry.btime.finderFormatted)
                }
                .customizationID("btime")
                .defaultVisibility(.hidden)
            }
            Group {
                TableColumn("Permissions", value: \ArchiveEntry.permsString) { entry in
                    @Bindable var entry = entry
                    Text(entry.perms.string)
                        .foregroundStyle(.secondary)
                        .popover(isPresented: $entry.permsPopoverShowing, arrowEdge: .bottom) {
                            PermsEditorView(entry: entry)
                        }
                        .onTapGesture(count: 2) {
                            entry.permsPopoverShowing = true
                        }
                    // FIXME: This isn't the same as a Force Touch press, which SwiftuI currently can't recognise. Can we hack it somehow? FB17662362
                        .onLongPressGesture {
                            entry.permsPopoverShowing = true
                        }
                        .accessibilityLabel("POSIX Permissions")
                        .accessibilityValue(entry.permsAccessibilityString)
                }
                .customizationID("perms")
                .defaultVisibility(.hidden)
                TableColumn("UID", value: \ArchiveEntry.uidString) { entry in
                    Text(entry.uidString)
                        .foregroundStyle(.secondary)
                }
                .customizationID("uid")
                .defaultVisibility(.hidden)
                TableColumn("GID", value: \ArchiveEntry.gidString) { entry in
                    Text(entry.gidString)
                        .foregroundStyle(.secondary)
                }
                .customizationID("gid")
                .defaultVisibility(.hidden)
                TableColumn("Synthetic", value: \ArchiveEntry.isSynthesizedString) { entry in
                    Text(entry.isSynthesizedString)
                        .foregroundStyle(.secondary)
                }
                .customizationID("synth")
                .defaultVisibility(.hidden)
                TableColumn("Symlink Target", value: \ArchiveEntry.symlinkTargetString) { entry in
                    Text(entry.symlinkTargetString)
                        .foregroundStyle(.secondary)
                }
                .customizationID("symlinkTarget")
                .defaultVisibility(.hidden)
                TableColumn("Major/Minor", value: \ArchiveEntry.rdevString) { entry in
                    Text(entry.rdevString)
                        .foregroundStyle(.secondary)
                }
                .customizationID("rdev")
                .defaultVisibility(.hidden)
            }
#if DEBUG
            Group {
                TableColumn("UUID (Debug)", value: \ArchiveEntry.id.uuidString)
                    .customizationID("uuid")
                    .defaultVisibility(.hidden)
                TableColumn("Source (Debug)", value: \ArchiveEntry.source.description)
                    .customizationID("source")
                    .defaultVisibility(.hidden)
                TableColumn("Path (Debug)", value: \ArchiveEntry.path)
                    .customizationID("path")
                    .defaultVisibility(.hidden)
                TableColumn("ID", value: \ArchiveEntry.id.uuidString)
                    .customizationID("id")
                    .defaultVisibility(.hidden)
            }
#endif
        } rows: {
            TableRowTreeContent(viewModel: viewModel, node: viewModel.root)
        }
        .dropDestination(for: DropItem.self) { items, _  in
            print("Table: dropDestination")
            viewModel.handleManyDrops(items: items)
            return true
        }
        .searchable(text: $viewModel.searchQuery, isPresented: $viewModel.searchPresented)
        .copyable(viewModel.buildCopyable(entryIDs: viewModel.selectedEntries))
        .cuttable(action: {
            viewModel.buildCuttable(entryIDs: viewModel.selectedEntries)
        })
        .onPasteCommand(of: [.archiveEntryExtractable, .fileURL], perform: { providers in
            viewModel.processDrop(for: providers)
        })
        .opacity(isEnabled ? 1.0 : 0.5)
        .contextMenu(forSelectionType: ArchiveEntry.ID.self) { items in
            EntryContextMenu(viewModel: viewModel, items: items)
        }
        .onKeyPress(.space, action: {
            if renameEntryFocus != nil {
                // We're renaming a file, we do not want to try and Quick Look it
                return .ignored
            }

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
    }
}

//#Preview {
//    let viewModel = MainWindowViewModel()
//
//    VStack {
//        TableView()
//            .environment(viewModel)
//    }
//    .toolbar(id: "Preview") {
//        ToolbarContentView(viewModel: viewModel)
//    }
//    .task {
//        viewModel.newButton()
//        try? viewModel.archive?.addFiles(from: [URL(fileURLWithPath:"/Users/cmsj/Desktop/")])
//    }
//}
