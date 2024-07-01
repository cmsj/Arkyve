//
//  SettingsManager.swift
//  ZipZap
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation
import ZZLog

struct SettingsManager {
    static let shared = SettingsManager()
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache")

    private init() {
        let msg = "Cache directory: \(cacheURL)"
        #ZZTrace(msg)
    }
}
