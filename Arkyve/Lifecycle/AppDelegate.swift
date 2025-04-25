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

//    func applicationWillTerminate(_ aNotification: Notification) {
//        #ZZTrace("Removing cache directories")
//        SettingsManager.shared.removeCacheDirectories()
//    }
}
