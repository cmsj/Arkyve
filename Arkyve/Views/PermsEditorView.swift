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
                    Toggle(isOn: $entry.perms.IRUSR) { Text("R") }
                    Toggle(isOn: $entry.perms.IWUSR) { Text("W") }
                    Toggle(isOn: $entry.perms.IXUSR) { Text("X") }
                    Toggle(isOn: $entry.perms.ISUSR) { Text("S") }
                }
                GridRow {
                    Text("Group:")
                    Toggle(isOn: $entry.perms.IRGRP) { Text("R") }
                    Toggle(isOn: $entry.perms.IWGRP) { Text("W") }
                    Toggle(isOn: $entry.perms.IXGRP) { Text("X") }
                    Toggle(isOn: $entry.perms.ISGRP) { Text("S") }

                }
                GridRow {
                    Text("Other:")
                    Toggle(isOn: $entry.perms.IROTH) { Text("R") }
                    Toggle(isOn: $entry.perms.IWOTH) { Text("W") }
                    Toggle(isOn: $entry.perms.IXOTH) { Text("X") }
                    Toggle(isOn: $entry.perms.ISVTX) { Text("S") }

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
