//
//  FormatPickerViewModel.swift
//  ZipZap
//
//  Created by Chris Jones on 16/01/2025.
//

import Synchronization
import SwiftUI

// The structure of this model class is taken from: https://forums.swift.org/t/do-update-to-observable-properties-have-to-be-done-on-the-main-thread/74954/5
@Observable
final class FormatPickerViewModel: Sendable {
    @ObservationIgnored
    fileprivate let _formatStorage = Mutex<libarchiveFormat>(.ZIP)
    @ObservationIgnored
    fileprivate let _filterStorage = Mutex<libarchiveFilter>(.None)

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
                }
            }
        }
    }

    public var filter: libarchiveFilter {
        get {
            return _filterStorage.withLock { value in
                self.access(keyPath: \.filter)
                return value
            }
        }
        set {
            self.withMutation(keyPath: \.filter) {
                _filterStorage.withLock { value in
                    value = newValue
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
