//
//  ArkyveApp.swift
//  Arkyve
//
//  Created by Chris Jones on 03/06/2025.
//

import SwiftUI
import TipKit

@main
struct ArkyveApp: App {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State var managerManager = ManagerManagerBase.shared
    @StateObject var settingsManager = SettingsManager.shared

    init() {
#if DEBUG
        try? Tips.resetDatastore()
#endif

        try? Tips.configure()
    }

    var body: some Scene {
        WindowGroup("Arkyve", id: "archive", for: UUID.self) { $archiveViewModelID in
            // WARNING: No logic is allowed here, otherwise you'll trigger defaultValue even when opening a file
            ArchiveView(id: archiveViewModelID)
                .environmentObject(settingsManager)
                .onOpenURL { url in
                    AKTrace("System opened URL: \(url)")
                    openWindow(id: "archive", value: managerManager.createVM(url: url).id)
                    settingsManager.addRecent(url)
                }
        } defaultValue: {
            AKTrace("WindowGroup default content initialiser")
            return UUID()
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands {
            MenuCommands(settingsManager: settingsManager)
        }
        .onChange(of: managerManager.vmStoreIsEmpty, initial: true) { wasEmpty, isEmpty in
            // NOTE: This is one half of a behaviour - the other half is an equivalent onChange in SplashView
            if isEmpty && settingsManager.autoSplashWindow {
                openWindow(id: "splash")
            }
        }
        .onChange(of: settingsManager.autoSplashWindow) { oldValue, newValue in
            // NOTE: This is one half of a behaviour - the other half is an equivalent onChange in SplashView
            if newValue == true && managerManager.vmStoreIsEmpty {
                print("Opening window")
                openWindow(id: "splash")
            }
        }

        Window("Recents Browser", id: "splash") {
            SplashView()
                .containerBackground(.thickMaterial, for: .window)
                .windowMinimizeBehavior(.disabled)
                .windowFullScreenBehavior(.disabled)
                .windowResizeBehavior(.disabled)
        }
        .windowBackgroundDragBehavior(.enabled)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        UtilityWindow("Log viewer", id: "log-window") {
            LogWindowView()
        }
        .defaultLaunchBehavior(.suppressed)

        Settings() {
            SettingsView()
                .environmentObject(settingsManager)
        }
    }
}
