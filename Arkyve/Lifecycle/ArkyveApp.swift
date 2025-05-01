//
//  ArkyveApp.swift
//  Arkyve
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import TipKit
import os

@main
struct ArkyveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var viewModel = MainWindowViewModel()

    init() {
#if DEBUG
        try? Tips.resetDatastore()
#endif

        try? Tips.configure()
    }

    var body: some Scene {
        Window(viewModel.navTitleText, id: "main") {
            MainWindowView()
                .environment(viewModel)
        }
        .commands {
            MenuCommands(viewModel: viewModel)
            ToolbarCommands()
        }

        UtilityWindow("Log viewer", id: "log-window") {
            LogWindowView()
        }
        .defaultLaunchBehavior(.suppressed)
    }
}
