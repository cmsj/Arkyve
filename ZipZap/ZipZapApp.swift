//
//  ZipZapApp.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI

struct SettingsManager {
    static let shared = SettingsManager()
    private init() { }

    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cache")
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
