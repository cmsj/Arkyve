//
//  PermsEditorView.swift
//  Arkyve
//
//  Created by Chris Jones on 03/05/2025.
//

import SwiftUI

struct PermsEditorView: View {
    @Bindable var entry: ArchiveEntry
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Spacer()
            Grid(alignment: .trailing) {
                GridRow {
                    Text("User:")
                    Toggle(isOn: $entry.perms.IRUSR) { Text("R").accessibilityLabel("Read") }
                    Toggle(isOn: $entry.perms.IWUSR) { Text("W").accessibilityLabel("Write") }
                    Toggle(isOn: $entry.perms.IXUSR) { Text("X").accessibilityLabel("Execute") }
                    Toggle(isOn: $entry.perms.ISUSR) { Text("S").accessibilityLabel("SetUID") }
                }
                GridRow {
                    Text("Group:")
                    Toggle(isOn: $entry.perms.IRGRP) { Text("R").accessibilityLabel("Read") }
                    Toggle(isOn: $entry.perms.IWGRP) { Text("W").accessibilityLabel("Write") }
                    Toggle(isOn: $entry.perms.IXGRP) { Text("X").accessibilityLabel("Execute") }
                    Toggle(isOn: $entry.perms.ISGRP) { Text("S").accessibilityLabel("SetGID") }

                }
                GridRow {
                    Text("Other:")
                    Toggle(isOn: $entry.perms.IROTH) { Text("R").accessibilityLabel("Read") }
                    Toggle(isOn: $entry.perms.IWOTH) { Text("W").accessibilityLabel("Write") }
                    Toggle(isOn: $entry.perms.IXOTH) { Text("X").accessibilityLabel("Execute") }
                    Toggle(isOn: $entry.perms.ISVTX) { Text("S").accessibilityLabel("Sticky") }

                }
            }
        }
        .padding()

        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .padding([.bottom])
            Spacer()

        }
    }
}

#Preview {
    PermsEditorView(entry: ArchiveEntry(syntheticDirectory: "testSynth"))
}
