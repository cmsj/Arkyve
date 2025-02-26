//
//  TableRowTreeContent.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import ZZLog

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
                .draggable(ArchiveEntryExtractable(showErrors: viewModel.showErrors,
                                                   archiveURL: viewModel.archive?.URL,
                                                   cacheURL: viewModel.archive?.cacheURL,
                                                   selectedPath: child.path,
                                                   id: child.id,
                                                   entries: child.flatChildren()))
                .dropDestination(for: Data.self) { items in
                    // FIXME: Implement
                    print("YO DROP DATA")
                }
            } else {
                TableRow(child)
                    .draggable(ArchiveEntryExtractable(showErrors: viewModel.showErrors,
                                                       archiveURL: viewModel.archive?.URL,
                                                       cacheURL: viewModel.archive?.cacheURL,
                                                       selectedPath: child.path,
                                                       id: child.id,
                                                       entries: child.flatChildren()))
            }
        }
        .onInsert(of: [ArchiveEntry.draggableType, .fileURL]) { index, providers in
            print("Received a drop at \(index) on \(String(describing:self))")
            viewModel.processDrop(at: index, on: node, for: providers);
        }
    }
}
