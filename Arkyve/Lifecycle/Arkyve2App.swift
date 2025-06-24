//
//  ArkyveApp.swift
//  Arkyve
//
//  Created by Chris Jones on 03/06/2025.
//

import SwiftUI
import TipKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag == false {
            // User clicked on the dock icon, but we have no windows open, so open the splash window
            AKTrace("Dock icon clicked while no windows are open, signalling Welcome window to open")
            if let url = URL(string:"arkyve://splash") {
                NSWorkspace.shared.open(url)
            }
        }
        return true
    }
}

@main
struct ArkyveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State var managerManager = ManagerManager.shared
    @StateObject var settingsManager = SettingsManager.shared

    init() {
//#if DEBUG
//        try? Tips.resetDatastore()
//#endif

        try? Tips.configure()
    }

    var body: some Scene {
        WindowGroup("Arkyve", id: "archive", for: UUID.self) { $archiveViewModelID in
            // WARNING: No logic is allowed here, otherwise you'll trigger defaultValue even when opening a file
            ArchiveView(id: archiveViewModelID)
                .environmentObject(settingsManager)
                .onOpenURL { url in
                    AKTrace("System opened URL: \(url)")
                    guard let lastDefaultID = managerManager.lastDefaultID else {
                        AKError("Unable to find lastDefaultID")
                        return
                    }
                    managerManager.reInitVM(lastDefaultID, for: url)
                    settingsManager.addRecent(url)
                    dismissWindow(id: "splash")
                }
        } defaultValue: {
            AKTrace("WindowGroup default content initialiser")
            let newID = UUID()
            managerManager.lastDefaultID = newID
            return newID
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .onChange(of: managerManager.vmStoreIsEmpty, initial: true) { wasEmpty, isEmpty in
            // NOTE: This is one half of a behaviour - the other half is an equivalent onChange in SplashView
            if isEmpty && settingsManager.autoSplashWindow && !AppInfo.shared.isRunningUnitTests {
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

        Window("Welcome to Arkyve", id: "splash") {
            SplashView()
                .containerBackground(.thickMaterial, for: .window)
                .windowMinimizeBehavior(.disabled)
                .windowResizeBehavior(.disabled)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: Set(arrayLiteral: "splash"))

        UtilityWindow("Log viewer", id: "log-window") {
            LogWindowView()
        }
        .defaultLaunchBehavior(.suppressed)

        Settings() {
            SettingsView()
                .environmentObject(settingsManager)
        }
        .commands {
            MenuCommands(settingsManager: settingsManager)
        }

        Window("About Arkyve", id: "about") {
            AboutView()
                .containerBackground(.thickMaterial, for: .window)
                .windowResizeBehavior(.disabled)
        }
        .commands {
            CommandGroup(replacing: .singleWindowList) {
                Button(action: {
                    openWindow(id: "splash")
                }) {
                    Text("Welcome to Arkyve")
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}
