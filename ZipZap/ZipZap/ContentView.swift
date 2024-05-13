//
//  ContentView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import Combine
import zzarchive

struct ContentView: View {
    @State var showFileChooser = false
    @State var windowTitle = "ZipZap"
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.pathname)]
    @State private var selectedEntries = Set<ArchiveEntry.ID>()
    @State private var dateFormatter = DateFormatter()
    @ObservedObject var archive = Archive()

    @SceneStorage("ArchiveEntryTableConfig")
    private var columnCustomization: TableColumnCustomization<ArchiveEntry>

    init() {
        self.dateFormatter.dateStyle = .long
        self.dateFormatter.timeStyle = .long
    }

    var body: some View {
        VStack {
            // TODO:
            //  * Sorting is sync, try to make it async
            //  * Can't sort by date columns, presumably because they're not keypath. Can we have them be keypath and still sort properly?
            //  * Figure out how to hide some columns by default
            Table(archive.entries, selection: $selectedEntries, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
                TableColumn("Name", value: \.pathname)
                    .customizationID("pathname")
                TableColumn("Size", value: \.sizeString)
                    .customizationID("sizeString")
                TableColumn("Date Modified") { entry in
                    Text(dateFormatter.string(from: entry.mtime))
                }
                    .customizationID("mtime")
                TableColumn("Date Changed") { entry in
                    Text(dateFormatter.string(from: entry.ctime))
                }
                    .customizationID("ctime")
                TableColumn("Date Accessed") { entry in
                    Text(dateFormatter.string(from: entry.atime))
                }
                    .customizationID("atime")
                TableColumn("Date Created") { entry in
                    Text(dateFormatter.string(from: entry.btime))
                }
                    .customizationID("btime")
            }
            .onChange(of: sortOrder) { _, sortOrder in
                archive.entries.sort(using: sortOrder)
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Open...") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            windowTitle = url.lastPathComponent
                            self.archive.setURL(url)
                        }
                    }
                }
            }
        }
        .navigationTitle(windowTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
