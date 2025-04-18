//
//  FormatPickerViewModel.swift
//  ZipZap
//
//  Created by Chris Jones on 16/01/2025.
//

import Foundation
import Synchronization
import SwiftUI

// The structure of this model class is taken from: https://forums.swift.org/t/do-update-to-observable-properties-have-to-be-done-on-the-main-thread/74954/5
@Observable
final class FormatPickerViewModel: Sendable {
    @ObservationIgnored
    fileprivate let _formatStorage = Mutex<libarchiveFormat>(.ZIP)
    @ObservationIgnored
    let panel: NSSavePanel?

    init(panel: NSSavePanel? = nil) {
        self.panel = panel
    }

    public var format: libarchiveFormat {
        get {
            return _formatStorage.withLock { value in
                self.access(keyPath: \.format)
                return value
            }
        }
        set {
            self.withMutation(keyPath: \.format) {
                _formatStorage.withLock { value in
                    value = newValue

                    Task { @MainActor in
                        if let panel {
                            let baseName = panel.nameFieldStringValue.deletingPathExtension
                            let ext = newValue.writeExtension
                            let newName = "\(baseName).\(ext)"
                            panel.nameFieldStringValue = newName
                        }
                    }
                }
            }
        }
    }
}

private struct FormatPickerViewModelEnvironmentKey: EnvironmentKey {
    static let defaultValue: FormatPickerViewModel = .init()
}

extension EnvironmentValues {
    var formatPickerViewModel: FormatPickerViewModel {
        get { self[FormatPickerViewModelEnvironmentKey.self] }
        set { self[FormatPickerViewModelEnvironmentKey.self] = newValue }
    }
}
