//
//  SettingsBehavioursView.swift
//  Arkyve
//
//  Created by Chris Jones on 05/06/2025.
//

import SwiftUI

struct SettingsBehavioursView: View {
    @EnvironmentObject private var settingsManager: SettingsManager

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Grid {
                    GridRow {
                        Text("When opening an archive:")
                            .foregroundStyle(.secondary)
                            .padding([.bottom], 10)
                            .gridCellColumns(2)
                    }
                    GridRow {
                        Text("Expand folders:")
                            .gridColumnAlignment(.trailing)
                        Picker("", selection: $settingsManager.folderExpansion) {
                            ForEach(FolderExpansionOptions.allCases, id: \.self) { format in
                                Text(format.description)
                                    .tag(format.rawValue)
                            }
                        }
                        .labelsHidden()
                        .gridColumnAlignment(.leading)
                    }
                    GridRow {
                        Text("When no archive is open:")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                            .gridCellColumns(2)
                    }
                    GridRow {
                        Text("Show splash screen:")
                        Toggle(isOn: $settingsManager.autoSplashWindow, label: {})
                            .labelsHidden()
                            .gridColumnAlignment(.leading)
                    }

                    Spacer()

                    #if DEBUG
                    GridRow {
                        Text("Show debug UI")
                        Toggle(isOn: $settingsManager.showDebugUI, label: {})
                            .labelsHidden()
                            .gridColumnAlignment(.leading)
                    }
                    #endif

                    GridRow {
                        Button("Reset all settings to defaults") {
                            let alert = NSAlert()
                            alert.addButton(withTitle: "Cancel")
                            alert.addButton(withTitle: "Reset")
                            alert.buttons.last?.hasDestructiveAction = true
                            alert.informativeText = "Are you sure you want to reset all settings to defaults?"

                            let response = alert.runModal()

                            // runModal() has various return values, we are going to ignore any that aren't specific button presses
                            switch response {
                            case .alertFirstButtonReturn:
                                // Cancel button, nothing to do here
                                break
                            case .alertSecondButtonReturn:
                                // Reset button
                                settingsManager.resetToDefaults()
                            default:
                                // This should never be hit
                                return
                            }
                        }
                        .gridCellColumns(2)
                    }
                    GridRow {
                        HStack {
                            Spacer()
                            Text("This will reset all General and Advanced settings to their default values.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(width: 300)
                            Spacer()
                        }
                        .gridCellColumns(2)
                    }
                }
                Spacer()
            }
            .frame(width: 400)
            .padding(.vertical)
            Spacer()
        }
        .overlay {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HelpLink(anchor: "advanced")
                        .padding()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager.shared)
}
