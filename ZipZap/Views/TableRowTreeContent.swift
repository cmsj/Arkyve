//
//  TableRowTreeContent.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import ZZLog
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
                .draggable(ArchiveEntryExtractable(archiveURL: viewModel.archive?.URL,
                                                   cacheURL: viewModel.archive?.cacheURL,
                                                   selectedPath: child.path,
                                                   id: child.id,
                                                   entries: child.flatChildren()))
                .dropDestination(for: DropItem.self) { items in
                    viewModel.handleManyDrops(on: child.id, items: items)
                }
            } else {
                TableRow(child)
                    .draggable(ArchiveEntryExtractable(archiveURL: viewModel.archive?.URL,
                                                       cacheURL: viewModel.archive?.cacheURL,
                                                       selectedPath: child.path,
                                                       id: child.id,
                                                       entries: child.flatChildren()))
            }
        }
        .onInsert(of: [.archiveEntryExtractable, .fileURL]) { index, providers in
            viewModel.processDrop(at: index, on: node, for: providers)
        }
    }
}
