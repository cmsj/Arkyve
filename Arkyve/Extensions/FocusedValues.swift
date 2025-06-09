//
//  FocusedValues.swift
//  Arkyve
//
//  Created by Chris Jones on 07/06/2025.
//

import SwiftUI

// create an active viewmodel key
struct ActiveViewModelKey: FocusedValueKey {
    typealias Value = ArchiveViewModel
}

extension FocusedValues {
    var activeViewModel: ArchiveViewModel? {
        get { self[ActiveViewModelKey.self] }
        set { self[ActiveViewModelKey.self] = newValue }
    }
}
