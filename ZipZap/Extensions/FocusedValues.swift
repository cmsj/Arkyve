//
//  FocusedValues.swift
//  ZipZap
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation
import SwiftUI

// These are used to determine which window has focus and let menus interact with the view model
struct ActiveViewModelKey: FocusedValueKey {
    typealias Value = MainWindowViewModel
}

extension FocusedValues {
    var activeViewModel: MainWindowViewModel? {
        get { self[ActiveViewModelKey.self] }
        set { self[ActiveViewModelKey.self] = newValue }
    }
}
