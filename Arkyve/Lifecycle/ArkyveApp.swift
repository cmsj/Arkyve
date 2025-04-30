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
    @State var viewModel = MainWindowViewModel()

    var body: some Scene {
        Window(viewModel.navTitleText, id: "main") {
            MainWindowView(viewModel: viewModel)
        }
        .commands {
            MenuCommands(viewModel: viewModel)
        }

        UtilityWindow("Log viewer", id: "log-window") {
            LogWindowView()
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
