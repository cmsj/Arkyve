//
//  CreateNewArchive.swift
//  Arkyve
//
//  Created by Chris Jones on 21/05/2025.
//

import TipKit
import SwiftUI

struct CreateNewArchive: Tip {
    static let noArchiveIsOpen: Event = Event(id: "noArchiveIsOpen")

    var title: Text {
        Text("Create a new archive")
    }
    var message: Text? {
        Text("You can create a new archive by clicking here, or dragging files/folders into the window.")
    }
    var image: Image? {
        Image("custom.folder.badge.sparkles.alt")
    }

    var rules: [Rule] {
        // Define a rule based on the interaction.
        #Rule(Self.noArchiveIsOpen) {
            // Set the conditions for when the tip displays.
            $0.donations.count > 0
        }
    }
}
