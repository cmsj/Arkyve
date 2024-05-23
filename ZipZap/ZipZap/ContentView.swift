//
//  ContentView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import os
import zzarchive

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

    @SceneStorage("ArchiveEntryTableConfig")
    private var columnCustomization: TableColumnCustomization<ArchiveEntry>

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ContentView.self)
    )

    var body: some View {
        VStack {
            // TODO:
            //  * Drag and drop on the TableRows
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
            ToolbarItem(id: "Extract"){
                Button {

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
