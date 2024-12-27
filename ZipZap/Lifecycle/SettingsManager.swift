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

    var newFolderURL: URL {
        get {
            UserDefaults.standard.url(forKey: "newFolderURL") ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        set(url) {
            UserDefaults.standard.setValue(url, forKey: "newFolderURL")
        }
    }

    private init() {
        let msg = "Cache directory: \(cacheURL)"
        #ZZTrace(msg)
    }
}
