//
//  TableRowTreeContent.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct TableRowTreeContent: TableRowContent {
    let node: ArchiveEntry?
    let viewModel: MainWindowViewModel

    var tableRowBody: some TableRowContent<ArchiveEntry> {
        ForEach(node?.children ?? []) { child in
            if let _ = child.children {
                @Bindable var child = child
                DisclosureTableRow(child, isExpanded: $child.isExpanded) {
                    TableRowTreeContent(node: child, viewModel: viewModel)
                }
                .contextMenu() {
                    EntryContextMenu(viewModel: viewModel, items: [child.id])
                }
                .draggable(child.asExtractable(for: viewModel.archive!))
                .dropDestination(for: DropItem.self) { items in
                    print("DisclosureTableRow: dropDestination")
                    viewModel.handleManyDrops(on: child.id, items: items)
                }
            } else {
                TableRow(child)
                    .contextMenu() {
                        EntryContextMenu(viewModel: viewModel, items: [child.id])
                    }
                    .draggable(child.asExtractable(for: viewModel.archive!))
            }
        }
        // FIXME: Add .image here when Apple fixes drag&drop. DTS filed
        .onInsert(of: [.archiveEntryExtractable, .fileURL]) { index, providers in
            print("TableRowTreeContent: onInsert")
            viewModel.processDrop(at: index, on: node?.id, for: providers)
        }
    }
}
