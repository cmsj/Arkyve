//
//  TableRowTreeContent.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import ZZLog
import UniformTypeIdentifiers

enum DropItem: Codable, Transferable {
    case none
    case file(URL)
    case entry(String)

    static var transferRepresentation: some TransferRepresentation {
//        ProxyRepresentation { DropItem.entry($0) }
        ProxyRepresentation { DropItem.file($0) }
    }

    var file: URL? {
        switch self {
        case .file(let url): return url
        default: return nil
        }
    }

    var entry: String? {
        switch self {
        case .entry(let entry): return entry
        default: return nil
        }
    }
}

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
//                .dropDestination(for: DropItem.self) { items in
//                    // FIXME: Implement
//                    print("YO DROP FILES")
//                    print(items)
//                }
//                .dropDestination(for: ArchiveEntry.draggableType.self) { items in
//                    print("YO DROP ENTRIES")
//                    print(items)
//                }
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
            print("Received a drop at \(index) on \(String(describing: self))")
            viewModel.processDrop(at: index, on: node, for: providers)
        }
    }
}
