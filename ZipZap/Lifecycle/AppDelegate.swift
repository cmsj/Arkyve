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
        SettingsManager.shared.removeCacheDirectories()
        SettingsManager.shared.createCacheDirectories()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        SettingsManager.shared.removeCacheDirectories()
    }
}
