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
                .disabled(activeViewModel == nil || activeViewModel?.archive == nil || activeViewModel?.archive?.dirty == false)
                Divider()
                Button("Save") {
                    activeViewModel?.saveButton()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(activeViewModel == nil || activeViewModel?.archive == nil || activeViewModel?.archive?.dirty == false)
            }
            CommandGroup(after: .sidebar) {
                Button("Quick Look") {
                    activeViewModel?.extractForQuicklook()
                }
                .keyboardShortcut("y", modifiers: [.command])
                .disabled(activeViewModel?.selectedEntries.count == 0)
                Divider()
            }
        }
//        .restorationBehavior(.disabled)

        #warning("Switch to UtilityWindow() once macOS 15 is released")
        Window("Log viewer", id: "log-window") {
            LogWindowView()
        }
//        .restorationBehavior(.disabled)
//        .defaultLaunchBehavior(.suppressed)
    }
    #warning("Enable restoration/launch behaviours when macOS 15 is released")
}
