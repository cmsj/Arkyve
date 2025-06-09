//
//  DateEditorView.swift
//  Arkyve
//
//  Created by Chris Jones on 03/05/2025.
//

import SwiftUI

struct DateEditorView: View {
    @Binding var selection: Date
    @Environment(\.dismiss) var dismiss

    var label: String

    var body: some View {
        VStack {
            Text(label)
            DatePicker("", selection: $selection)

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
        .padding()
    }
}

#Preview {
    @Previewable @State var date = Date()
    DateEditorView(selection: $date, label: "Test Label")
}
