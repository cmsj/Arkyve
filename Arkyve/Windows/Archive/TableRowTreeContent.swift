//
//  TableRowTreeContent.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct TableRowTreeContent: TableRowContent {
    var viewModel: ArchiveViewModel
    var node: ArchiveEntry

    var tableRowBody: some TableRowContent<ArchiveEntry> {
        ForEach(node.children!.filter { viewModel.searchQuery == "" || $0.hasSelfOrChildrenMatching(viewModel.searchQuery)}) { child in
            if let _ = child.children {
                @Bindable var child = child
                DisclosureTableRow(child, isExpanded: $child.isExpanded) {
                    TableRowTreeContent(viewModel: viewModel, node: child)
                }
                .draggable(child.asExtractable(from: viewModel.diskURL, cacheURL: viewModel.cacheURL, vmID: viewModel.id))
                .dropDestination(for: DropItem.self) { items in
                    print("DisclosureTableRow: dropDestination")
                    viewModel.handleManyDrops(on: child.id, items: items)
                }
            } else {
                TableRow(child)
                    .draggable(child.asExtractable(from: viewModel.diskURL, cacheURL: viewModel.cacheURL, vmID: viewModel.id))
            }
        }
        .onInsert(of: [.archiveEntryExtractable, .fileURL]) { index, providers in
            print("TableRowTreeContent: onInsert")
            viewModel.processDrop(at: index, on: node.id, for: providers)
        }
    }
}
