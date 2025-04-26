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
        AKTrace("Creating cache directories")
        SettingsManager.shared.removeCacheDirectories()
        SettingsManager.shared.createCacheDirectories()
    }

    // For now we're a one-window app and managing window lifecycles is not really a great fit for the way we work, so we'll quit if our window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // FIXME: Implement the delegate method required for when we've been opened with a file. Actually this is a SwiftUI thing

// We can't do this if we're also reacting to it in MainWindowView, because this one fires first and breaks saving operations
//    func applicationWillTerminate(_ aNotification: Notification) {
//        AKTrace("Removing cache directories")
//        SettingsManager.shared.removeCacheDirectories()
//    }
}
