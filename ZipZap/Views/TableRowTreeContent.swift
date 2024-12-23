//
//  TableRowTreeContent.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import ZZLog

struct TableRowTreeContent: TableRowContent {
    let children: [ArchiveEntry]
    let viewModel: MainWindowViewModel

    var tableRowBody: some TableRowContent<ArchiveEntry> {
        ForEach(children) { child in
            if let children = child.children {
                @Bindable var child = child
                DisclosureTableRow(child, isExpanded: $child.isExpanded) {
                    TableRowTreeContent(children: children, viewModel: viewModel)
                }
                .draggable(ArchiveEntryExtractable(showErrors: viewModel.showErrors,
                                                   archiveURL: viewModel.archive?.URL,
                                                   cacheURL: viewModel.archive?.cacheURL,
                                                   selectedPath: child.path,
                                                   entries: child.flatChildren()))
            } else {
                TableRow(child)
                    .draggable(ArchiveEntryExtractable(showErrors: viewModel.showErrors,
                                                       archiveURL: viewModel.archive?.URL,
                                                       cacheURL: viewModel.archive?.cacheURL,
                                                       selectedPath: child.path,
                                                       entries: child.flatChildren()))
            }
        }
    }
}



// TODO: WRITE
//        .onInsert(of: [ArchiveEntry.draggableType, .fileURL]) { index, providers in
//            let error = "Received a drop! Index: \(index) on \(String(describing: self))"
//            #ZZTrace(error)
//
//            // FIXME: This needs to:
//            //   * Find the relevant ArchiveEntry that describes the folder the drag happened into
//            //   * .fileURL - a net new file coming from Finder/wherever, create an ArchiveEntry for it and insert into the folder
//            //   * ArchiveEntry.draggableType - an ArchiveEntry being re-ordered from elsewhere in the table. Remove it from its current parent and add it to the drag-destination folder
//
//            // Greedily consume any provider that is coming from us
//            let internalDropProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(ArchiveEntry.draggableType.identifier) }
//            let externalDropProviders = providers.filter {
//                // Internal drops still include public.file-url, so we only want ones here that don't also contain ArchiveEntry.draggableType
//                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) && !internalDropProviders.contains($0)
//            }
//
//            viewModel.archive?.processInternalDrop(providers: internalDropProviders, atIndex: index, treeHint: self.children)
//            viewModel.archive?.processExternalDrop(providers: externalDropProviders, atIndex: index, treeHint: self.children)
//        }
