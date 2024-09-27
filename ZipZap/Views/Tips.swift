//
//  Tips.swift
//  ZipZap
//
//  Created by Chris Jones on 27/09/2024.
//
import TipKit

struct TableViewTip: Tip {
    var id = "listingTableTip"
    var title: Text {
        Text("Archive contents")
    }
    var message: Text? {
        Text("When an archive is open, its contents will be displayed here")
    }
    var image: Image? {
        Image(systemName: "list.bullet.indent")
    }
}

struct OpenButtonTip: Tip {
    var id = "openButtonTip"
    var title: Text {
        Text("Open an archive")
    }
    var message: Text? {
        Text("Use this button to open an archive")
    }
    var image: Image? {
        Image(systemName: "folder")
    }
}
