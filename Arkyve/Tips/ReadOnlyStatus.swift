//
//  ReadOnlyStatus.swift
//  Arkyve
//
//  Created by Chris Jones on 01/05/2025.
//

import TipKit
import SwiftUI

struct ReadOnlyStatus: Tip {
    static let didOpenReadOnly: Event = Event(id: "didOpenReadOnly")

    var title: Text {
        Text("Read-only archive")
    }
    var message: Text? {
        Text("This archive's format is read-only. Use Save As to select a writable format if you need to make changes.")
    }
    var image: Image? {
        Image(systemName: "square.and.arrow.down")
    }

    var rules: [Rule] {
        // Define a rule based on the interaction.
        #Rule(Self.didOpenReadOnly) {
            // Set the conditions for when the tip displays.
            $0.donations.count > 0
        }
    }
}
