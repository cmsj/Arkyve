//
//  SettingsView.swift
//  Arkyve
//
//  Created by Chris Jones on 31/05/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        TabView {
            SettingsPathsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            SettingsBehavioursView()
                .tabItem {
                    Label("Advanced", systemImage: "square.stack.3d.down.right")
                }
        }
        .frame(width: 750, height: 400)
        .onKeyPress { action in
            if action.key == "w" && action.modifiers == [.command] {
                dismiss()
                return .handled
            }
            return .ignored
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}
