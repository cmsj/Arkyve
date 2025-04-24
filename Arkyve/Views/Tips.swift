//
//  Tips.swift
//  Arkyve
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

struct NewButtonTip: Tip {
    var id = "newButtonTip"
    var title: Text {
        Text("Start a new, empty archive")
    }
    var message: Text? {
        Text("Use this button to start a new, empty archive")
    }
    var image: Image? {
        Image(systemName: "plus.rectangle.on.folder")
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

struct CloseButtonTip: Tip {
    var id = "closeButtonTip"
    var title: Text {
        Text("Close this archive")
    }
    var message: Text? {
        Text("Use this button to close the current archive")
    }
    var image: Image? {
        Image("zzClose")
    }
}
