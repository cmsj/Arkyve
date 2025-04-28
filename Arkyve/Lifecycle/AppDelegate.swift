//
//  AppDelegate.swift
//  Arkyve
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

    // For now we're a one-window app and managing window lifecycles is not really a great fit for the way we work, so we'll quit if our window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
