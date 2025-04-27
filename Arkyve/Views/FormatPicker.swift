//
//  FormatPicker.swift
//  Arkyve
//
//  Created by Chris Jones on 16/01/2025.
//

import SwiftUI


struct FormatPicker: View {
    @Environment(\.formatPickerViewModel) var viewModel: FormatPickerViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        HStack {
            Picker(selection: $viewModel.format, label: Text("Format")) {
                ForEach(ArkyveFormats.allCases) { format in
                    Text(format.description)
                        .tag(format)
                }
            }
            .padding()
        }
    }
}
