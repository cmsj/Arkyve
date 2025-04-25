//
//  AppDelegate.swift
//  Arkyve
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation
import SwiftUI
import ZZLog

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        #ZZTrace("Creating cache directories")
        SettingsManager.shared.removeCacheDirectories()
        SettingsManager.shared.createCacheDirectories()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

// We can't do this if we're also reacting to it in MainWindowView, because this one fires first and breaks saving operations
//    func applicationWillTerminate(_ aNotification: Notification) {
//        #ZZTrace("Removing cache directories")
//        SettingsManager.shared.removeCacheDirectories()
//    }
}
