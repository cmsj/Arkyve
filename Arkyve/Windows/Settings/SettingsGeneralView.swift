//
//  NewFolderPickerValues.swift
//  Arkyve
//
//  Created by Chris Jones on 05/06/2025.
//

import SwiftUI

enum NewFolderPickerValues: String, CaseIterable, Identifiable {
    case url, select
    var id: Self { self }
}

struct SettingsPathsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var newFolderPicker: NewFolderPickerValues = .url
    @State private var icon = NSImage(size: .init(width: 12, height: 12))

    @ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 12

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Grid {
                    GridRow {
                        Text("For new archives:")
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
                        HStack {
                            Picker("", selection: $settingsManager.newArchiveFormat) {
                                ForEach(ArkyveFormats.writeableCases, id: \.self) { format in
                                    Text(format.description)
                                        .tag(format.rawValue)
                                }
                            }
                            .labelsHidden()

                            HelpLink(anchor: "formats-table", book: "net.tenshu.ArkyveHelp")
                        }
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
                    GridRow {
                        Text("When viewing an archive:")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                            .gridCellColumns(2)
                    }
                    GridRow {
                        Text("Icon size:")
                        Picker("", selection: $settingsManager.iconSize) {
                            Image(nsImage: NSWorkspace.shared.icon(for: .data))
                                .resizable()
                                .scaledToFit()
                                .frame(height: 16)
                                .tag(16)
                            Image(nsImage: NSWorkspace.shared.icon(for: .data))
                                .resizable()
                                .scaledToFit()
                                .frame(height: 32)
                                .tag(32)
                        }
                        .pickerStyle(.radioGroup)
                        .horizontalRadioGroupLayout()
                        .labelsHidden()
                        .gridColumnAlignment(.leading)
                    }
                    GridRow {
                        Text("Use relative dates:")
                        Toggle(isOn: $settingsManager.relativeDates, label: {})
                            .labelsHidden()
                            .gridColumnAlignment(.leading)
                    }
                }
                Spacer()
            }
            .frame(width: 700)
            .padding(.vertical)
            Spacer()
        }
    }
}
