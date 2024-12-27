//
//  AppDelegate.swift
//  ZipZap
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        do {
            try FileManager.default.createDirectory(at: SettingsManager.shared.cacheURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: SettingsManager.shared.writeCacheURL, withIntermediateDirectories: true)
        } catch {
            fatalError("Unable to create cache directories at \(SettingsManager.shared.cacheURL) and \(SettingsManager.shared.writeCacheURL)")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        try? FileManager.default.removeItem(at: SettingsManager.shared.cacheURL)
        try? FileManager.default.removeItem(at: SettingsManager.shared.writeCacheURL)
    }
}
