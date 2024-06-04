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
    }
}
