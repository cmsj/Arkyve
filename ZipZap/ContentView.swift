//
//  ContentView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import os
//import archive


// This seems to be too dynamic, it's causing rerenders for every tiny change, even selecting rows
struct NestedTree: TableRowContent {
    let children : [ ArchiveEntry ]

    var tableRowBody: some TableRowContent<ArchiveEntry> {
        ForEach(children) { child in
            if let children = child.children {
                @Bindable var child = child
                DisclosureTableRow(child, isExpanded: $child.isExpanded) {
                    NestedTree(children: children)
                }
                .itemProvider { child.itemProvider }
            }
            else {
                TableRow(child)
                    .itemProvider { child.itemProvider }
            }
        }
    }
}

struct ContentView: View {
    @State var showFileChooser = false
    @State var windowTitle = "ZipZap"
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.path)]
    @State private var selectedEntries = Set<ArchiveEntry.ID>()
    @State var archive: Archive? = nil

    @AppStorage("default-new-folder") var newFolderURL: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @SceneStorage("ArchiveEntryTableConfig")
    private var columnCustomization: TableColumnCustomization<ArchiveEntry>

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ContentView.self)
    )

    var body: some View {
        VStack {
            // TODO:
            //  * Column default width
            //  * Sorting is broken, it's still sorting archive.entries. Instead we should sort the contents of every directory in the tree
            Table(of: ArchiveEntry.self, selection: $selectedEntries, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
                TableColumn("Name") { entry in
                    HStack {
                        Image(systemName: entry.type.rawValue)
                        Text(entry.name)
                    }
                }
                .customizationID("name")
                TableColumn("Size", value: \.sizeString)
                    .customizationID("sizeString")
                    .alignment(.trailing)
                TableColumn("Date Modified", value: \.mtime.userFormatted)
                    .customizationID("mtime")
                TableColumn("Permissions", value: \.perms)
                    .customizationID("perms")
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
                NestedTree(children: archive?.root.children ?? [])
            }
            .onChange(of: sortOrder) { _, sortOrder in
                archive?.sort(using: sortOrder)
            }

            // Status bar
            ZStack {
                HStack {
                    Spacer()
                    Text(archive?.error ?? "")
                    Spacer()
                }
                HStack {
                    Spacer()
                    Text("\(archive?.entries.count ?? 0) items")
                        .opacity(archive == nil || archive?.error != nil ? 0 : 1)
                        .padding([.trailing])
                }
                .padding([.top, .bottom])
            }
        }
        .toolbar(id: "Main") {
            ToolbarItem(id: "New") {
                Button {
                    self.archive = Archive(name: "Untitled.zip", URL: newFolderURL.appendingPathComponent("Untitled.zip"))
                } label: {
                    Label("New", systemImage: "folder.badge.plus")
                        .padding()
                }
            }
            ToolbarItem(id: "Open") {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            windowTitle = url.lastPathComponent
                            self.archive = Archive(name: windowTitle, URL: url)
                            self.archive?.open()
                        }
                    }
                } label: {
                    Label("Open...", systemImage: "folder")
                        .padding()
                }
            }
            ToolbarItem(id: "Add"){
                Button {

                } label: {
                    Label("Add", systemImage: "plus")
                        .padding()
                }
                .disabled(archive == nil)
            }
            ToolbarItem(id: "Extract"){
                Button {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            _ = archive?.extractEntries(selectedEntries, toFolder: url)
                        }
                    }
                } label: {
                    Label("Extract", systemImage: "folder.badge.minus")
                        .padding()
                }
                .disabled(selectedEntries.isEmpty)
            }
        }
        .navigationTitle(windowTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
