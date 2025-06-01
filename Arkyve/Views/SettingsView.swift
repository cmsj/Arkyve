//
//  SettingsView.swift
//  Arkyve
//
//  Created by Chris Jones on 31/05/2025.
//

import SwiftUI

enum NewFolderPickerValues: String, CaseIterable, Identifiable {
    case url, select
    var id: Self { self }
}

struct SettingsPathsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var newFolderPicker: NewFolderPickerValues = .url
    @State private var icon: NSImage = .customFolderSlash

    @ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 12

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Grid {
                    GridRow {
                        Text("Default behaviours for new archives:")
                            .foregroundStyle(.secondary)
                            .padding([.bottom])
                            .gridCellColumns(2)
                    }
                    GridRow {
                        Text("Default name:")
                            .gridColumnAlignment(.trailing)
                        TextField("", text: $settingsManager.newArchiveName, prompt: Text("New Archive Name (required)"))
                            .labelsHidden()
                    }
                    GridRow {
                        Text("Default format:")
                        Picker("", selection: $settingsManager.newArchiveFormat) {
                            ForEach(ArkyveFormats.writeableCases, id: \.self) { format in
                                Text(format.description)
                                    .tag(format.rawValue)
                            }
                        }
                        .labelsHidden()
                    }
                    GridRow {
                        Color.clear
//                            .frame(height: 10)
                            .gridCellUnsizedAxes([.horizontal, .vertical])
                            .padding(.vertical, 5)
                    }
                    GridRow {
                        Text("Save new archives to:")
                        Picker("", selection: $newFolderPicker) {
                            HStack {
                                Image(nsImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: iconSize)
                                Text(settingsManager.newFolderURL.lastPathComponent)
                            }
                            .tag(NewFolderPickerValues.url)
                            Divider()
                            Text("Select new location")
                                .tag(NewFolderPickerValues.select)
                        }
                        .labelsHidden()
                        .onChange(of: newFolderPicker, initial: true) {
                            if newFolderPicker == .select {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.canCreateDirectories = true
                                panel.allowsMultipleSelection = false

                                if panel.runModal() == .OK {
                                    if let url = panel.url {
                                        settingsManager.newFolderURL = url
                                    }
                                }
                            }
                            newFolderPicker = .url
                            icon = NSWorkspace.shared.icon(forFile: settingsManager.newFolderURL.path)
                            icon.size = .init(width: iconSize, height: iconSize)
                        }
                    }
                }
                Spacer()
            }
            .frame(width: 400)
            .padding(.vertical)
            Spacer()
        }
    }
}

struct SettingsBehavioursView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var cacheReadSize = -1
    @State private var cacheWriteSize = -1
    @State private var cacheDropSize = -1

    var body: some View {
        VStack {
            Grid {
                GridRow {
                    Text("When opening an archive:")
                        .foregroundStyle(.secondary)
                        .padding([.bottom])
                        .gridCellColumns(2)
                }
                GridRow {
                    Text("Expand folders:")
                    Toggle(isOn: $settingsManager.expandSingleRootFolder, label: {
                        Text("If archive contains only one folder")
                    })
                    .gridColumnAlignment(.leading)
                }
                GridRow {
                    Text("")
                    Toggle(isOn: $settingsManager.expandAllFolders, label: {
                        Text("Always")
                    })
                    .gridColumnAlignment(.leading)
                }
//#if DEBUG
//                Spacer()
//                GridRow {
//                    Text("Cache sizes:")
//                        .foregroundStyle(.secondary)
//                        .padding([.bottom])
//                        .gridCellColumns(2)
//                }
//
//                GridRow {
//                    Text("Read cache:")
//                        .gridColumnAlignment(.trailing)
//                    Text("\(cacheReadSize != -1 ? cacheReadSize.human : "not read yet")")
//                }
//                GridRow {
//                    Text("Write cache:")
//                        .gridColumnAlignment(.trailing)
//                    Text("\(cacheWriteSize != -1 ? cacheWriteSize.human : "not read yet")")
//                }
//                GridRow {
//                    Text("Drag&drop cache:")
//                        .gridColumnAlignment(.trailing)
//                    Text("\(cacheDropSize != -1 ? cacheDropSize.human : "not read yet")")
//                }
//
//                GridRow {
//                    Button("Update cache sizes") {
//                        (cacheReadSize, cacheWriteSize, cacheDropSize) = CacheManager.shared.cacheSizes()
//                    }
//                    .gridCellColumns(2)
//                }
//#endif
                Spacer()
                GridRow {
                    Button("Reset all settings to defaults") {
                        let alert = NSAlert.init()
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
        .padding()
    }
}

struct SettingsView: View {
    @Environment(MainWindowViewModel.self) var viewModel
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
        .environment(MainWindowViewModel())
        .environmentObject(SettingsManager())
}
