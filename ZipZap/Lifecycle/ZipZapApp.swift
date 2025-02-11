//
//  ZipZapApp.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import os
import ZZLog

@main
struct ZipZapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.activeViewModel) var activeViewModel

    var body: some Scene {
        Window("ZipZap", id: "main") {
            MainWindowView()
        }
        .commands {
            MenuCommands()
        }
        .restorationBehavior(.disabled)

        UtilityWindow("Log viewer", id: "log-window") {
            LogWindowView()
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
