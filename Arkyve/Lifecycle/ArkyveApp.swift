//
//  ArkyveApp.swift
//  Arkyve
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import os

@main
struct ArkyveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.activeViewModel) var activeViewModel

    var body: some Scene {
        Window(activeViewModel?.navTitleText ?? "Arkyve", id: "main") {
            MainWindowView()
        }
        .commands {
            MenuCommands()
        }

        UtilityWindow("Log viewer", id: "log-window") {
            LogWindowView()
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
