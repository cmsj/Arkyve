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

// These are used to determine which window has focus and let menus interact with the view model
struct ActiveViewModelKey: FocusedValueKey {
    typealias Value = MainWindowViewModel
}

extension FocusedValues {
    var activeViewModel: MainWindowViewModel? {
        get { self[ActiveViewModelKey.self] }
        set { self[ActiveViewModelKey.self] = newValue }
    }
}

@main
struct ZipZapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.activeViewModel) var activeViewModel

    var body: some Scene {
        WindowGroup(id: "archive-window") {
            MainWindowView()
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open...") {
                    activeViewModel?.openButton()
                }
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(activeViewModel == nil)
                Button("Revert") {
                    activeViewModel?.revertButton()
                }
                .disabled(activeViewModel == nil || activeViewModel?.archive?.dirty == false)
            }
            CommandGroup(after: .sidebar) {
                Button("Quick Look") {
                    guard activeViewModel != nil else { return }
                    activeViewModel?.extractForQuicklook()
                }
                .keyboardShortcut("y", modifiers: [.command])
                .disabled(activeViewModel?.selectedEntries.count == 0)
                Divider()
            }
        }
        // FIXME: Enable this once macOS 15 is released:
//        .restorationBehavior(.disabled)

        // FIXME: Switch to UtilityWindow() once macOS 15 is out
        Window("Log viewer", id: "log-window") {
            LogWindowView()
        }
        // FIXME: Enable these once macOS 15 is released:
//        .restorationBehavior(.disabled)
//        .defaultLaunchBehavior(.suppressed)
    }
}
