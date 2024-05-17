//
//  ContentView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import os
import zzarchive

struct ContentView: View {
    @State var showFileChooser = false
    @State var windowTitle = "ZipZap"
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.path)]
    @State private var selectedEntries = Set<ArchiveEntry.ID>()
    @ObservedObject var archive = Archive()

    @SceneStorage("ArchiveEntryTableConfig")
    private var columnCustomization: TableColumnCustomization<ArchiveEntry>

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ContentView.self)
    )

    var body: some View {
        VStack {
            // TODO:
            //  * Figure out how to hide some columns by default
            //  * Parse pathname to make a hierarchy and switch this to what we have in TestView
            //  * Drag and drop on the TableRows
            Table(of: ArchiveEntry.self, selection: $selectedEntries, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
                TableColumn("Type") { entry in
                    Image(systemName: entry.type.rawValue)
                }
                    .customizationID("type")
                TableColumn("Name", value: \.path)
                    .customizationID("pathname")
                TableColumn("Size", value: \.sizeString)
                    .customizationID("sizeString")
                    .alignment(.trailing)
                TableColumn("Date Modified", value: \.mtime.userFormatted)
                    .customizationID("mtime")
                TableColumn("Date Changed", value: \.ctime.userFormatted)
                    .customizationID("ctime")
                TableColumn("Date Accessed", value: \.atime.userFormatted)
                    .customizationID("atime")
                TableColumn("Date Created", value: \.btime.userFormatted)
                    .customizationID("btime")
            } rows: {
                ForEach(archive.entries) { entry in
                    TableRow(entry)
                }
            }
            .id(UUID()) // Hack to make the table more performant on large archives. https://stackoverflow.com/questions/59604764/performance-issue-with-swiftui-list
            .onChange(of: sortOrder) { _, sortOrder in
                archive.sort(using: sortOrder)
            }
            HStack {
                Spacer()
                Text("\(archive.entries.count) items")
                Spacer()
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
                            self.archive.setURL(url)
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
