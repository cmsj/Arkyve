//
//  Tips.swift
//  Arkyve
//
//  Created by Chris Jones on 06/06/2025.
//

import TipKit
import SwiftUI

struct ReadOnlyStatus: Tip {
    static let event: Event = Event(id: "didOpenReadOnly")

    var title: Text {
        Text("Read-only archive")
    }
    var message: Text? {
        Text("This archive's format is read-only. Use Save As to select a writable format if you need to make changes.")
    }
    var image: Image? {
        Image("custom.pencil.slash")
    }

    var rules: [Rule] {
        // Define a rule based on the interaction.
        #Rule(Self.event) {
            // Set the conditions for when the tip displays.
            $0.donations.count > 0
        }
    }
}
