//
//  FormatPickerViewModel.swift
//  Arkyve
//
//  Created by Chris Jones on 16/01/2025.
//

import Foundation
import Synchronization
import SwiftUI

// The structure of this model class is taken from: https://forums.swift.org/t/do-update-to-observable-properties-have-to-be-done-on-the-main-thread/74954/5
@Observable
final class FormatPickerViewModel: NSObject, Sendable, NSOpenSavePanelDelegate {
    @ObservationIgnored
    fileprivate let _formatStorage = Mutex<ArkyveFormats>(.zip)
    @ObservationIgnored
    let panel: NSSavePanel?

    init(panel: NSSavePanel? = nil) {
        self.panel = panel
    }

    var format: ArkyveFormats {
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

                    guard let panel = panel else { return }
                    Task { @MainActor in
                        let newName = panel.nameFieldStringValue.deletingPathExtension// + ".\(newValue.ext)"
                        print("Updating panel name to \(newName)")
                        panel.nameFieldStringValue = newName
                    }
                }
            }
        }
    }

    func panel(_ sender: Any, userEnteredFilename filename: String, confirmed okFlag: Bool) -> String? {
        print("User entered filename: \(filename)")
        return filename + ".\(format.ext)"
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
