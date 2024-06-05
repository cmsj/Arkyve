//
//  TableRowTreeContent.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI

struct TableRowTreeContent: TableRowContent {
    let children : [ ArchiveEntry ]

    var tableRowBody: some TableRowContent<ArchiveEntry> {
        ForEach(children) { child in
            if let children = child.children {
                @Bindable var child = child
                DisclosureTableRow(child, isExpanded: $child.isExpanded) {
                    TableRowTreeContent(children: children)
                }
                .itemProvider { child.itemProvider }
            }
            else {
                TableRow(child)
                    .itemProvider { child.itemProvider }
            }
        }
        .onInsert(of: [ArchiveEntry.draggableType, .fileURL]) { index, providers in
            print("Received an internal drop! Index: \(index) on \(String(describing: self))")
            for provider in providers {
                // FIXME: This needs to:
                //   * Find the relevant ArchiveEntry that describes the folder the drag happened into
                //   * .fileURL - a net new file coming from Finder/wherever, create an ArchiveEntry for it and insert into the folder
                //   * ArchiveEntry.draggableType - an ArchiveEntry being re-ordered from elsewhere in the table. Remove it from its current parent and add it to the drag-destination folder
                print(provider.registeredTypeIdentifiers)
            }
        }
    }
}
