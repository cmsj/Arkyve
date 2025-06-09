//
//  ErrorManager.swift
//  Arkyve
//
//  Created by Chris Jones on 06/06/2025.
//

import SwiftUI

@Observable
@MainActor
class ErrorManager {
    var show: Bool = false
    var error: ArkyveError? = nil

    func err(_ error: ArkyveError) {
        self.error = error
        AKError("Displayed error: \(error.localizedDescription)")
    }

    func clear() {
        self.error = nil
    }
}
