//
//  ZipZapApp.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import os
import ZZLog

#warning("Remove this typealias (and the `import os` above) when Swift 6 adds its native Mutex type")
typealias Mutex = OSAllocatedUnfairLock

struct SettingsManager {
    static let shared = SettingsManager()
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache")

    private init() {
        let msg = "Cache directory: \(cacheURL)"
        #ZZTrace(msg)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        do {
            try FileManager.default.createDirectory(at: SettingsManager.shared.cacheURL, withIntermediateDirectories: true)
        } catch {
            fatalError("Unable to create cache directory at \(SettingsManager.shared.cacheURL)")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        try? FileManager.default.removeItem(at: SettingsManager.shared.cacheURL)
    }
}

@main
struct ZipZapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }
        .windowToolbarStyle(.expanded)
    }
}
